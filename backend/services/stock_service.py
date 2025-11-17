# backend/services/stock_service.py
from fastapi import HTTPException
from sqlalchemy.orm import Session
from repositories.product_repository import ProductRepository
from repositories.location_repository import LocationRepository
from repositories.stock_repository import StockRepository
from schemas.item import StockItemCreate, StockItemCreateFromScan, StockItem
from schemas.stock_update import StockUpdate
from typing import List

class StockService:
    def __init__(self, db: Session):
        self.product_repo = ProductRepository(db)
        self.location_repo = LocationRepository(db)
        self.stock_repo = StockRepository(db)
        self.db = db

    def process_manual_stock(self, item_data: StockItemCreate, user_id: str) -> StockItem:
        # 1. Validar que la ubicación pertenece al usuario.
        # Buscamos la ubicación por su ID y nos aseguramos de que el user_id coincida.
        ubicacion = self.location_repo.get_location_by_id_and_user(item_data.ubicacion_id, user_id)
        if not ubicacion:
            raise HTTPException(status_code=404, detail=f"Ubicación no encontrada o no tienes permiso sobre ella.")

        # 2. Buscar o crear el producto en el catálogo maestro global.
        # Si se proporciona un barcode, se usa para buscar/crear. Si no, se usa el nombre.
        if item_data.barcode:
            producto_maestro = self.product_repo.get_or_create_by_barcode(
                barcode=item_data.barcode,
                name=item_data.product_name,
                brand=item_data.brand,
                user_id=user_id, # Pasamos el user_id
                image_url=item_data.image_url # Pasamos la URL de la imagen
            )
        else:
            producto_maestro = self.product_repo.get_or_create_by_name(item_data.product_name, user_id)
        
        if not producto_maestro:
             raise HTTPException(status_code=500, detail="No se pudo crear o encontrar el producto maestro.")

        # 3. Lógica de agrupación: Buscar si ya existe este producto en esta ubicación para este usuario.
        existing_stock_item = self.stock_repo.find_stock_item(
            user_id=user_id,
            producto_maestro_id=producto_maestro.id_producto,
            ubicacion_id=ubicacion.id_ubicacion,
            fecha_caducidad=item_data.fecha_caducidad
        )

        if existing_stock_item:
            # Si existe, sumamos la cantidad y actualizamos.
            existing_stock_item.cantidad_actual += item_data.cantidad
            new_stock_item = self.stock_repo.update_stock_item(existing_stock_item)
        else:
            # Si no existe, creamos una nueva entrada.
            new_stock_item = self.stock_repo.create_stock_item(
                user_id=user_id,
                fk_producto_maestro=producto_maestro.id_producto,
                fk_ubicacion=ubicacion.id_ubicacion,
                cantidad_actual=item_data.cantidad,
                fecha_caducidad=item_data.fecha_caducidad
            )
        
        # Devolvemos un objeto de respuesta completo, no solo el objeto de la BD.
        # SQLAlchemy nos permite acceder a las relaciones para obtener los nombres.
        return StockItem.from_orm(new_stock_item)

    def process_scan_stock(self, item_data: StockItemCreateFromScan, user_id: str) -> StockItem:
        # 1. Validar que la ubicación pertenece al usuario.
        ubicacion = self.location_repo.get_location_by_id_and_user(item_data.ubicacion_id, user_id)
        if not ubicacion:
            raise HTTPException(status_code=404, detail=f"Ubicación no encontrada o no tienes permiso sobre ella.")

        # 2. Buscar o crear el producto en el catálogo maestro usando el barcode.
        producto_maestro = self.product_repo.get_or_create_by_barcode(
            barcode=item_data.barcode,
            name=item_data.product_name,
            brand=item_data.brand,
            user_id=user_id, # Pasamos el user_id
            image_url=item_data.image_url # Pasamos la URL de la imagen
        )

        # 3. Lógica de agrupación: Buscar si ya existe este producto en esta ubicación para este usuario.
        existing_stock_item = self.stock_repo.find_stock_item(
            user_id=user_id,
            producto_maestro_id=producto_maestro.id_producto,
            ubicacion_id=ubicacion.id_ubicacion,
            fecha_caducidad=item_data.fecha_caducidad
        )

        if existing_stock_item:
            # Si existe, sumamos la cantidad y actualizamos.
            existing_stock_item.cantidad_actual += item_data.cantidad
            new_stock_item = self.stock_repo.update_stock_item(existing_stock_item)
        else:
            # Si no existe, creamos una nueva entrada.
            new_stock_item = self.stock_repo.create_stock_item(
                user_id=user_id,
                fk_producto_maestro=producto_maestro.id_producto,
                fk_ubicacion=ubicacion.id_ubicacion,
                cantidad_actual=item_data.cantidad,
                fecha_caducidad=item_data.fecha_caducidad
            )
        
        # Devolvemos el objeto de respuesta completo.
        return StockItem.from_orm(new_stock_item)

    def get_stock_for_user(self, user_id: str, search: str | None) -> List[StockItem]:
        stock_items = self.stock_repo.get_all_stock_for_user(user_id, search)
        return [StockItem.from_orm(item) for item in stock_items]

    def consume_stock_item(self, id_stock: int, user_id: str) -> dict:
        # 1. Buscar el item y validar que pertenece al usuario.
        item_to_consume = self.stock_repo.get_stock_item_by_id_and_user(id_stock, user_id)

        if not item_to_consume:
            raise HTTPException(status_code=404, detail="Producto no encontrado en tu inventario.")

        # 2. Reducir la cantidad.
        item_to_consume.cantidad_actual -= 1

        # 3. Comprobar si la cantidad es cero para eliminarlo.
        if item_to_consume.cantidad_actual <= 0:
            self.stock_repo.delete_stock_item(item_to_consume)
            return {"status": "deleted", "message": "Producto consumido y eliminado del inventario."}
        else:
            # Si todavía quedan unidades, actualizamos la BD.
            self.stock_repo.update_stock_item(item_to_consume)
            return {
                "status": "updated",
                "message": "Cantidad reducida en 1.",
                "new_quantity": item_to_consume.cantidad_actual
            }

    def remove_stock_quantity(self, id_stock: int, cantidad: int, user_id: str) -> dict:
        # 1. Validar que la cantidad sea positiva.
        if cantidad <= 0:
            raise HTTPException(status_code=400, detail="La cantidad a eliminar debe ser mayor que cero.")

        # 2. Buscar el item y validar que pertenece al usuario.
        item_to_remove_from = self.stock_repo.get_stock_item_by_id_and_user(id_stock, user_id)

        if not item_to_remove_from:
            raise HTTPException(status_code=404, detail="Producto no encontrado en tu inventario.")

        # 3. Validar que hay suficiente stock.
        if item_to_remove_from.cantidad_actual < cantidad:
            raise HTTPException(status_code=409, detail=f"No hay suficiente stock. Cantidad actual: {item_to_remove_from.cantidad_actual}, intentas eliminar: {cantidad}.")

        # 4. Reducir la cantidad o eliminar el item.
        item_to_remove_from.cantidad_actual -= cantidad
        if item_to_remove_from.cantidad_actual <= 0:
            self.stock_repo.delete_stock_item(item_to_remove_from)
            return {"status": "deleted", "message": f"Se eliminaron {cantidad} unidades. El producto ha sido retirado del inventario."}
        else:
            self.stock_repo.update_stock_item(item_to_remove_from)
            return {"status": "updated", "message": f"Se eliminaron {cantidad} unidades.", "new_quantity": item_to_remove_from.cantidad_actual}

    def update_stock_item_details(self, id_stock: int, user_id: str, payload: StockUpdate) -> StockItem:
        """Actualiza campos editables de un item de stock y opcionalmente del producto maestro asociado."""
        item = self.stock_repo.get_stock_item_by_id_and_user(id_stock, user_id)
        if not item:
            raise HTTPException(status_code=404, detail="Item de stock no encontrado.")

        # Actualizar producto maestro si se ha cambiado nombre o marca
        producto_maestro = item.producto_maestro
        if payload.product_name is not None:
            producto_maestro.nombre = payload.product_name
        if payload.brand is not None:
            producto_maestro.marca = payload.brand

        # Actualizar fecha de caducidad
        if payload.fecha_caducidad is not None:
            item.fecha_caducidad = payload.fecha_caducidad

        # Actualizar cantidad
        if payload.cantidad_actual is not None:
            if payload.cantidad_actual < 0:
                raise HTTPException(status_code=400, detail="La cantidad no puede ser negativa.")
            item.cantidad_actual = payload.cantidad_actual
            if item.cantidad_actual == 0:
                # Si queda en cero lo eliminamos y devolvemos info mínima
                self.stock_repo.delete_stock_item(item)
                raise HTTPException(status_code=200, detail="Item eliminado al establecer cantidad en 0.")

        # Actualizar ubicación
        if payload.ubicacion_id is not None:
            nueva_ubicacion = self.location_repo.get_location_by_id_and_user(payload.ubicacion_id, user_id)
            if not nueva_ubicacion:
                raise HTTPException(status_code=404, detail="Nueva ubicación no válida para este usuario.")
            item.fk_ubicacion = nueva_ubicacion.id_ubicacion

        # Persistir cambios (producto maestro y stock item)
        self.db.commit()
        self.db.refresh(item)
        self.db.refresh(producto_maestro)
        return StockItem.from_orm(item)