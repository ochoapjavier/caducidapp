# backend/repositories/stock_repository.py
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_
from datetime import date, timedelta
from models import InventoryStock, Product, Location

class StockRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_stock_item(self, user_id: str, fk_producto_maestro: int, fk_ubicacion: int, cantidad_actual: int, fecha_caducidad: date) -> InventoryStock:
        new_item = InventoryStock(
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

    def find_stock_item(self, user_id: str, producto_maestro_id: int, ubicacion_id: int, fecha_caducidad: date) -> InventoryStock | None:
        """
        Busca un item de stock específico por producto, ubicación, usuario y fecha de caducidad.
        Esto es clave para la lógica de agrupación.
        """
        return self.db.query(InventoryStock).filter(
            and_(
                InventoryStock.user_id == user_id,
                InventoryStock.fk_producto_maestro == producto_maestro_id,
                InventoryStock.fk_ubicacion == ubicacion_id,
                InventoryStock.fecha_caducidad == fecha_caducidad
            )
        ).first()

    def get_alertas_caducidad_for_user(self, days: int, user_id: str) -> list[InventoryStock]:
        today = date.today()
        limit_date = today + timedelta(days=days)

        return (
            self.db.query(InventoryStock)
            .options(
                joinedload(InventoryStock.producto_maestro),
                joinedload(InventoryStock.ubicacion)
            )
            .filter(
                InventoryStock.user_id == user_id,
                InventoryStock.fecha_caducidad >= today,
                InventoryStock.fecha_caducidad <= limit_date
            )
            .order_by(InventoryStock.fecha_caducidad)
            .all()
        )

    def get_stock_item_by_id_and_user(self, id_stock: int, user_id: str) -> InventoryStock | None:
        return self.db.query(InventoryStock).filter(
            InventoryStock.id_stock == id_stock,
            InventoryStock.user_id == user_id
        ).first()

    def get_all_stock_for_user(self, user_id: str, search_term: str | None = None) -> list[InventoryStock]:
        query = (
            self.db.query(InventoryStock)
            .options(
                joinedload(InventoryStock.ubicacion) # Mantenemos el joinedload para ubicacion
            )
            .join(Product) # Hacemos un JOIN explícito con Product
            .filter(InventoryStock.user_id == user_id)
        )

        if search_term:
            # Buscamos en el nombre del producto o en el código de barras
            search = f"%{search_term.lower()}%"
            query = query.filter(
                (Product.nombre.ilike(search)) |
                (Product.barcode.ilike(search))
            )

        return query.order_by(Product.nombre, InventoryStock.fecha_caducidad).all()

    def delete_stock_item(self, item: InventoryStock):
        self.db.delete(item)
        self.db.commit()
    
    def update_stock_item(self, item: InventoryStock):
        self.db.commit()
        self.db.refresh(item)
        return item
    