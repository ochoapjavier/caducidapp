# backend/repositories/stock_repository.py
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_
from datetime import date, timedelta
from models import InventoryStock, Product, Location

class StockRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_stock_item(self, hogar_id: int, fk_producto_maestro: int, fk_ubicacion: int, cantidad_actual: int, fecha_caducidad: date) -> InventoryStock:
        """Create a new stock item in a household."""
        new_item = InventoryStock(
            hogar_id=hogar_id,
            fk_producto_maestro=fk_producto_maestro,
            fk_ubicacion=fk_ubicacion,
            cantidad_actual=cantidad_actual,
            fecha_caducidad=fecha_caducidad
        )
        self.db.add(new_item)
        self.db.commit()
        self.db.refresh(new_item)
        return new_item

    def find_stock_item(self, hogar_id: int, producto_maestro_id: int, ubicacion_id: int, fecha_caducidad: date) -> InventoryStock | None:
        """
        Find specific stock item by product, location, household and expiration date.
        This is key for grouping logic.
        """
        return self.db.query(InventoryStock).filter(
            and_(
                InventoryStock.hogar_id == hogar_id,
                InventoryStock.fk_producto_maestro == producto_maestro_id,
                InventoryStock.fk_ubicacion == ubicacion_id,
                InventoryStock.fecha_caducidad == fecha_caducidad
            )
        ).first()

    def get_alertas_caducidad_for_hogar(self, days: int, hogar_id: int) -> list[InventoryStock]:
        """
        Get expiration alerts for a household.
        
        Rules:
        - EXCLUDES frozen products (estado_producto='congelado')
        - INCLUDES opened products ALWAYS (regardless of days)
        - INCLUDES products (opened or closed) expiring in <= days
        - INCLUDES already expired products
        - EXCLUDES frozen products
        """
        today = date.today()
        limit_date = today + timedelta(days=days)

        return (
            self.db.query(InventoryStock)
            .options(
                joinedload(InventoryStock.producto_maestro),
                joinedload(InventoryStock.ubicacion)
            )
            .filter(
                InventoryStock.hogar_id == hogar_id,
                InventoryStock.estado_producto != 'congelado',  # EXCLUDE frozen
                InventoryStock.fecha_caducidad <= limit_date  # Only soon-expiring items
            )
            .order_by(
                InventoryStock.fecha_caducidad
            )
            .all()
        )

    def get_stock_item_by_id_and_hogar(self, id_stock: int, hogar_id: int) -> InventoryStock | None:
        """Get stock item by ID within a household."""
        return self.db.query(InventoryStock).filter(
            InventoryStock.id_stock == id_stock,
            InventoryStock.hogar_id == hogar_id
        ).first()

    def get_all_stock_for_hogar(self, hogar_id: int, search_term: str | None = None) -> list[InventoryStock]:
        """Get all stock items for a household, with optional search."""
        query = (
            self.db.query(InventoryStock)
            .options(
                joinedload(InventoryStock.ubicacion)  # Keep joinedload for location
            )
            .join(Product)  # Explicit JOIN with Product
            .filter(InventoryStock.hogar_id == hogar_id)
        )

        if search_term:
            # Search in product name or barcode
            search = f"%{search_term.lower()}%"
            query = query.filter(
                (Product.nombre.ilike(search)) |
                (Product.barcode.ilike(search))
            )

        return query.order_by(Product.nombre, InventoryStock.fecha_caducidad).all()

    def delete_stock_item(self, item: InventoryStock):
        """Delete a stock item."""
        self.db.delete(item)
        self.db.commit()
    
    def update_stock_item(self, item: InventoryStock):
        """Update a stock item."""
        self.db.commit()
        self.db.refresh(item)
        return item
    