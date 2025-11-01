# backend/services/stock_service.py
from fastapi import HTTPException
from sqlalchemy.orm import Session
from repositories.producto_maestro_repository import ProductoMaestroRepository
from repositories.ubicacion_repository import UbicacionRepository
from repositories.stock_repository import StockRepository
from schemas.item import ItemCreate, ItemCreateFromScan, Item
from typing import List

class StockService:
    def __init__(self, db: Session):
        self.producto_repo = ProductoMaestroRepository(db)
        self.ubicacion_repo = UbicacionRepository(db)
        self.stock_repo = StockRepository(db)
        self.db = db

    def process_manual_stock(self, item_data: ItemCreate, user_id: str) -> Item:
        # 1. Validar que la ubicación pertenece al usuario.
        # Buscamos la ubicación por su ID y nos aseguramos de que el user_id coincida.
        ubicacion = self.ubicacion_repo.get_ubicacion_by_id_and_user(item_data.ubicacion_id, user_id)
        if not ubicacion:
            raise HTTPException(status_code=404, detail=f"Ubicación no encontrada o no tienes permiso sobre ella.")

        # 2. Buscar o crear el producto en el catálogo maestro global.
        # Esta lógica es para productos sin código de barras.
        producto_maestro = self.producto_repo.get_or_create_by_name(item_data.product_name)
        
        if not producto_maestro:
             raise HTTPException(status_code=500, detail="No se pudo crear o encontrar el producto maestro.")

        # 3. Crear la entrada en el inventario del usuario, ahora con todos los datos validados.
        new_stock_item = self.stock_repo.create_stock_item(
            user_id=user_id,
            fk_producto_maestro=producto_maestro.id_producto,
            fk_ubicacion=ubicacion.id_ubicacion,
            cantidad_actual=item_data.cantidad,
            fecha_caducidad=item_data.fecha_caducidad
        )
        
        # Devolvemos un objeto de respuesta completo, no solo el objeto de la BD.
        # SQLAlchemy nos permite acceder a las relaciones para obtener los nombres.
        return Item.from_orm(new_stock_item)

    def process_scan_stock(self, item_data: ItemCreateFromScan, user_id: str) -> Item:
        # 1. Validar que la ubicación pertenece al usuario.
        ubicacion = self.ubicacion_repo.get_ubicacion_by_id_and_user(item_data.ubicacion_id, user_id)
        if not ubicacion:
            raise HTTPException(status_code=404, detail=f"Ubicación no encontrada o no tienes permiso sobre ella.")

        # 2. Buscar o crear el producto en el catálogo maestro usando el barcode.
        producto_maestro = self.producto_repo.get_or_create_by_barcode(
            barcode=item_data.barcode,
            name=item_data.product_name,
            brand=item_data.brand
        )

        # 3. Crear la entrada en el inventario del usuario.
        new_stock_item = self.stock_repo.create_stock_item(
            user_id=user_id,
            fk_producto_maestro=producto_maestro.id_producto,
            fk_ubicacion=ubicacion.id_ubicacion,
            cantidad_actual=item_data.cantidad,
            fecha_caducidad=item_data.fecha_caducidad
        )
        
        # Devolvemos el objeto de respuesta completo.
        return Item.from_orm(new_stock_item)

    def get_stock_for_user(self, user_id: str, search: str | None) -> List[Item]:
        stock_items = self.stock_repo.get_all_stock_for_user(user_id, search)
        return [Item.from_orm(item) for item in stock_items]

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