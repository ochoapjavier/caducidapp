# backend/services/stock_service.py
from fastapi import HTTPException
from sqlalchemy.orm import Session
from repositories import ProductoRepository, UbicacionRepository, StockRepository
from schemas import ItemCreate

class StockService:
    def __init__(self, db: Session):
        self.producto_repo = ProductoRepository(db)
        self.ubicacion_repo = UbicacionRepository(db)
        self.stock_repo = StockRepository(db)

    def process_manual_stock(self, item_data: ItemCreate):
        producto_id = self.producto_repo.get_or_create_producto_maestro(item_data.nombre_producto)
        
        ubicacion_id = self.ubicacion_repo.get_ubicacion_id_by_name(item_data.nombre_ubicacion)

        if ubicacion_id is None:
            raise HTTPException(status_code=404, detail=f"Ubicación '{item_data.nombre_ubicacion}' no encontrada.")

        stock_id = self.stock_repo.add_stock_item(
            producto_id, 
            ubicacion_id, 
            item_data.cantidad, 
            item_data.fecha_caducidad
        )
        return {"id_stock": stock_id, "status": "Stock añadido con éxito"}
