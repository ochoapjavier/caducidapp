# backend/repositories/stock_repository.py
from sqlalchemy.orm import Session, joinedload
from datetime import date, timedelta
from typing import List
from .models import InventarioStock, ProductoMaestro, Ubicacion

class StockRepository:
    def __init__(self, db: Session):
        self.db = db

    def add_stock_item(self, prod_id: int, ubic_id: int, cantidad: int, fecha: date) -> InventarioStock:
        nuevo_item = InventarioStock(
            fk_producto_maestro=prod_id,
            fk_ubicacion=ubic_id,
            cantidad_actual=cantidad,
            fecha_caducidad=fecha,
            estado='Activo'
        )
        self.db.add(nuevo_item)
        self.db.commit()
        self.db.refresh(nuevo_item)
        return nuevo_item

    def get_alertas_caducidad(self, days: int = 7) -> List[InventarioStock]:
        fecha_inicio = date.today()
        fecha_fin = fecha_inicio + timedelta(days=days)
        
        return (
            self.db.query(InventarioStock)
            .join(ProductoMaestro, InventarioStock.fk_producto_maestro == ProductoMaestro.id_producto)
            .join(Ubicacion, InventarioStock.fk_ubicacion == Ubicacion.id_ubicacion)
            .options(joinedload(InventarioStock.producto_obj), joinedload(InventarioStock.ubicacion_obj))
            .filter(
                InventarioStock.estado == 'Activo',
                InventarioStock.fecha_caducidad.between(fecha_inicio, fecha_fin)
            )
            .order_by(InventarioStock.fecha_caducidad.asc())
            .all()
        )