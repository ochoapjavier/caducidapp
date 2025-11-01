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

    def get_stock_item_by_id_and_user(self, id_stock: int, user_id: str) -> InventarioStock | None:
        return self.db.query(InventarioStock).filter(
            InventarioStock.id_stock == id_stock,
            InventarioStock.user_id == user_id
        ).first()

    def get_all_stock_for_user(self, user_id: str, search_term: str | None = None) -> list[InventarioStock]:
        query = (
            self.db.query(InventarioStock)
            .options(
                joinedload(InventarioStock.ubicacion) # Mantenemos el joinedload para ubicacion
            )
            .join(ProductoMaestro) # Hacemos un JOIN explícito con ProductoMaestro
            .filter(InventarioStock.user_id == user_id)
        )

        if search_term:
            # Buscamos en el nombre del producto o en el código de barras
            search = f"%{search_term.lower()}%"
            query = query.filter(
                (ProductoMaestro.nombre.ilike(search)) |
                (ProductoMaestro.barcode.ilike(search))
            )

        return query.order_by(ProductoMaestro.nombre, InventarioStock.fecha_caducidad).all()

    def delete_stock_item(self, item: InventarioStock):
        self.db.delete(item)
        self.db.commit()
    
    def update_stock_item(self, item: InventarioStock):
        self.db.commit()
        self.db.refresh(item)
        return item
    