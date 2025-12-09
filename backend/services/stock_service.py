# backend/services/stock_service.py
from fastapi import HTTPException
from sqlalchemy.orm import Session
from repositories.product_repository import ProductRepository
from repositories.location_repository import LocationRepository
from repositories.stock_repository import StockRepository
from schemas.item import StockItemCreate, StockItemCreateFromScan, StockItem
from schemas.stock_update import StockUpdate
from typing import List
from datetime import datetime

class StockService:
    def __init__(self, db: Session):
        self.product_repo = ProductRepository(db)
        self.location_repo = LocationRepository(db)
        self.stock_repo = StockRepository(db)
        self.db = db

    def process_manual_stock(self, item_data: StockItemCreate, hogar_id: int, user_id: str) -> StockItem:
        """Process manually entered stock item for a household."""
        # 1. Validate that location belongs to household
        ubicacion = self.location_repo.get_location_by_id_and_hogar(item_data.ubicacion_id, hogar_id)
        if not ubicacion:
            raise HTTPException(status_code=404, detail=f"Ubicación no encontrada o no pertenece a este hogar.")

        # 2. Find or create product in household catalog
        producto_maestro = None
        
        if item_data.product_id:
            producto_maestro = self.product_repo.get_by_id(item_data.product_id)
            if producto_maestro and producto_maestro.hogar_id != hogar_id:
                producto_maestro = None

        if not producto_maestro:
            # If barcode is provided, use it for search/create. Otherwise, use name.
            if item_data.barcode:
                producto_maestro = self.product_repo.get_or_create_by_barcode(
                    barcode=item_data.barcode,
                    name=item_data.product_name,
                    brand=item_data.brand,
                    hogar_id=hogar_id,
                    image_url=item_data.image_url
                )
            else:
                producto_maestro = self.product_repo.get_or_create_by_name(
                    name=item_data.product_name, 
                    hogar_id=hogar_id,
                    brand=item_data.brand
                )
        
        if not producto_maestro:
             raise HTTPException(status_code=500, detail="No se pudo crear o encontrar el producto maestro.")

        # 3. Grouping logic: Check if this product already exists in this location
        existing_stock_item = self.stock_repo.find_stock_item(
            hogar_id=hogar_id,
            producto_maestro_id=producto_maestro.id_producto,
            ubicacion_id=ubicacion.id_ubicacion,
            fecha_caducidad=item_data.fecha_caducidad
        )

        if existing_stock_item:
            # If exists, add quantity and update
            existing_stock_item.cantidad_actual += item_data.cantidad
            new_stock_item = self.stock_repo.update_stock_item(existing_stock_item)
        else:
            # If not exists, create new entry
            estado_producto = 'cerrado'
            fecha_congelacion = None
            
            if ubicacion.es_congelador:
                estado_producto = 'congelado'
                fecha_congelacion = datetime.utcnow().date()

            new_stock_item = self.stock_repo.create_stock_item(
                hogar_id=hogar_id,
                fk_producto_maestro=producto_maestro.id_producto,
                fk_ubicacion=ubicacion.id_ubicacion,
                cantidad_actual=item_data.cantidad,
                fecha_caducidad=item_data.fecha_caducidad,
                estado_producto=estado_producto,
                fecha_congelacion=fecha_congelacion
            )
        
        # Return complete response object
        return StockItem.from_orm(new_stock_item)

    def process_scan_stock(self, item_data: StockItemCreateFromScan, hogar_id: int, user_id: str) -> StockItem:
        """Process scanned barcode stock item for a household."""
        # 1. Validate that location belongs to household
        ubicacion = self.location_repo.get_location_by_id_and_hogar(item_data.ubicacion_id, hogar_id)
        if not ubicacion:
            raise HTTPException(status_code=404, detail=f"Ubicación no encontrada o no pertenece a este hogar.")

        # 2. Find or create product using barcode
        producto_maestro = self.product_repo.get_or_create_by_barcode(
            barcode=item_data.barcode,
            name=item_data.product_name,
            brand=item_data.brand,
            hogar_id=hogar_id,
            image_url=item_data.image_url
        )

        # 3. Grouping logic: Check if this product already exists in this location
        existing_stock_item = self.stock_repo.find_stock_item(
            hogar_id=hogar_id,
            producto_maestro_id=producto_maestro.id_producto,
            ubicacion_id=ubicacion.id_ubicacion,
            fecha_caducidad=item_data.fecha_caducidad
        )

        if existing_stock_item:
            # If exists, add quantity and update
            existing_stock_item.cantidad_actual += item_data.cantidad
            new_stock_item = self.stock_repo.update_stock_item(existing_stock_item)
        else:
            # If not exists, create new entry
            estado_producto = 'cerrado'
            fecha_congelacion = None
            
            if ubicacion.es_congelador:
                estado_producto = 'congelado'
                fecha_congelacion = datetime.utcnow().date()

            new_stock_item = self.stock_repo.create_stock_item(
                hogar_id=hogar_id,
                fk_producto_maestro=producto_maestro.id_producto,
                fk_ubicacion=ubicacion.id_ubicacion,
                cantidad_actual=item_data.cantidad,
                fecha_caducidad=item_data.fecha_caducidad,
                estado_producto=estado_producto,
                fecha_congelacion=fecha_congelacion
            )
        
        # Return complete response object
        return StockItem.from_orm(new_stock_item)

    def get_stock_for_hogar(self, hogar_id: int, search: str | None) -> List[StockItem]:
        """Get all stock items for a household."""
        stock_items = self.stock_repo.get_all_stock_for_hogar(hogar_id, search)
        return [StockItem.from_orm(item) for item in stock_items]

    def consume_stock_item(self, id_stock: int, hogar_id: int) -> dict:
        """Consume one unit of a stock item."""
        # 1. Find item and validate it belongs to household
        item_to_consume = self.stock_repo.get_stock_item_by_id_and_hogar(id_stock, hogar_id)

        if not item_to_consume:
            raise HTTPException(status_code=404, detail="Producto no encontrado en el inventario.")

        # 2. Reduce quantity
        item_to_consume.cantidad_actual -= 1

        # 3. Check if quantity is zero to delete it
        if item_to_consume.cantidad_actual <= 0:
            self.stock_repo.delete_stock_item(item_to_consume)
            return {"status": "deleted", "message": "Producto consumido y eliminado del inventario."}
        else:
            # If units remain, update database
            self.stock_repo.update_stock_item(item_to_consume)
            return {
                "status": "updated",
                "message": "Cantidad reducida en 1.",
                "new_quantity": item_to_consume.cantidad_actual
            }

    def remove_stock_quantity(self, id_stock: int, cantidad: int, hogar_id: int) -> dict:
        """Remove specific quantity from stock item."""
        # 1. Validate positive quantity
        if cantidad <= 0:
            raise HTTPException(status_code=400, detail="La cantidad a eliminar debe ser mayor que cero.")

        # 2. Find item and validate it belongs to household
        item_to_remove_from = self.stock_repo.get_stock_item_by_id_and_hogar(id_stock, hogar_id)

        if not item_to_remove_from:
            raise HTTPException(status_code=404, detail="Producto no encontrado en el inventario.")

        # 3. Validate sufficient stock
        if item_to_remove_from.cantidad_actual < cantidad:
            raise HTTPException(status_code=409, detail=f"No hay suficiente stock. Cantidad actual: {item_to_remove_from.cantidad_actual}, intentas eliminar: {cantidad}.")

        # 4. Reduce quantity or delete item
        item_to_remove_from.cantidad_actual -= cantidad
        if item_to_remove_from.cantidad_actual <= 0:
            self.stock_repo.delete_stock_item(item_to_remove_from)
            return {"status": "deleted", "message": f"Se eliminaron {cantidad} unidades. El producto ha sido retirado del inventario."}
        else:
            self.stock_repo.update_stock_item(item_to_remove_from)
            return {"status": "updated", "message": f"Se eliminaron {cantidad} unidades.", "new_quantity": item_to_remove_from.cantidad_actual}

    def update_stock_item_details(self, id_stock: int, hogar_id: int, payload: StockUpdate) -> StockItem:
        """Update editable fields of a stock item and optionally the associated master product."""
        item = self.stock_repo.get_stock_item_by_id_and_hogar(id_stock, hogar_id)
        if not item:
            raise HTTPException(status_code=404, detail="Item de stock no encontrado.")

        # Update master product if name or brand changed
        producto_maestro = item.producto_maestro
        if payload.product_name is not None:
            producto_maestro.nombre = payload.product_name
        if payload.brand is not None:
            producto_maestro.marca = payload.brand

        # Update expiration date
        if payload.fecha_caducidad is not None:
            item.fecha_caducidad = payload.fecha_caducidad

        # Update quantity
        if payload.cantidad_actual is not None:
            if payload.cantidad_actual < 0:
                raise HTTPException(status_code=400, detail="La cantidad no puede ser negativa.")
            item.cantidad_actual = payload.cantidad_actual
            if item.cantidad_actual == 0:
                # If zero, delete it
                self.stock_repo.delete_stock_item(item)
                raise HTTPException(status_code=200, detail="Item eliminado al establecer cantidad en 0.")

        # Update location
        if payload.ubicacion_id is not None:
            nueva_ubicacion = self.location_repo.get_location_by_id_and_hogar(payload.ubicacion_id, hogar_id)
            if not nueva_ubicacion:
                raise HTTPException(status_code=404, detail="Nueva ubicación no válida para este hogar.")
            item.fk_ubicacion = nueva_ubicacion.id_ubicacion

        # Persist changes (master product and stock item)
        self.db.commit()
        self.db.refresh(item)
        self.db.refresh(producto_maestro)
        return StockItem.from_orm(item)