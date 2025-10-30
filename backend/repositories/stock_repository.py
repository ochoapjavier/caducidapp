# backend/repositories/stock_repository.py
from sqlalchemy.orm import Session, joinedload
from datetime import date, timedelta
from .models import InventarioStock, ProductoMaestro, Ubicacion

class StockRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_stock_item(self, user_id: str, fk_producto_maestro: int, fk_ubicacion: int, cantidad_actual: int, fecha_caducidad: date) -> InventarioStock:
        new_item = InventarioStock(
            user_id=user_id,
            fk_producto_maestro=fk_producto_maestro,
            fk_ubicacion=fk_ubicacion,
            cantidad_actual=cantidad_actual,
            fecha_caducidad=fecha_caducidad
        )
        self.db.add(new_item)
        self.db.commit()
        self.db.refresh(new_item)
        return new_item

    def get_alertas_caducidad_for_user(self, days: int, user_id: str) -> list[InventarioStock]:
        today = date.today()
        limit_date = today + timedelta(days=days)

        return (
            self.db.query(InventarioStock)
            .options(
                joinedload(InventarioStock.producto_maestro),
                joinedload(InventarioStock.ubicacion)
            )
            .filter(
                InventarioStock.user_id == user_id,
                InventarioStock.fecha_caducidad >= today,
                InventarioStock.fecha_caducidad <= limit_date
            )
            .order_by(InventarioStock.fecha_caducidad)
            .all()
        )