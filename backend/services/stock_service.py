# backend/services/stock_service.py
from fastapi import HTTPException
from sqlalchemy.orm import Session
from repositories.producto_repository import ProductoRepository
from repositories.ubicacion_repository import UbicacionRepository
from repositories.stock_repository import StockRepository
from schemas.item import ItemCreate
from repositories.models import InventarioStock

class StockService:
    def __init__(self, db: Session):
        self.producto_repo = ProductoRepository(db)
        self.ubicacion_repo = UbicacionRepository(db)
        self.stock_repo = StockRepository(db)

    def process_manual_stock(self, item_data: ItemCreate) -> InventarioStock:
        producto = self.producto_repo.get_or_create_producto_maestro(item_data.nombre_producto)
        
        ubicacion = self.ubicacion_repo.get_ubicacion_by_name(item_data.nombre_ubicacion)

        if ubicacion is None:
            raise HTTPException(status_code=404, detail=f"Ubicación '{item_data.nombre_ubicacion}' no encontrada.")

        return self.stock_repo.add_stock_item(
            producto.id_producto,
            ubicacion.id_ubicacion,
            item_data.cantidad,
            item_data.fecha_caducidad
        )