# backend/repositories/stock_repository.py
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_, or_
from datetime import date, timedelta
from models import InventoryStock, Product, Location

class StockRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_stock_item(self, hogar_id: int, fk_producto_maestro: int, fk_ubicacion: int, cantidad_actual: int, fecha_caducidad: date, estado_producto: str = 'cerrado', fecha_congelacion: date | None = None) -> InventoryStock:
        """Create a new stock item in a household."""
        new_item = InventoryStock(
            hogar_id=hogar_id,
            fk_producto_maestro=fk_producto_maestro,
            fk_ubicacion=fk_ubicacion,
            cantidad_actual=cantidad_actual,
            fecha_caducidad=fecha_caducidad,
            estado_producto=estado_producto,
            fecha_congelacion=fecha_congelacion
        )
        self.db.add(new_item)
        
        # Smart Grouping: Update product's last known location
        product = self.db.query(Product).filter(Product.id_producto == fk_producto_maestro).first()
        if product:
            product.last_location_id = fk_ubicacion
            self.db.add(product)

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
        - INCLUDES unfrozen products ALWAYS (highest priority - need quick consumption)
        - INCLUDES opened products ALWAYS (regardless of days)
        - INCLUDES products (opened or closed) expiring in <= days
        - INCLUDES already expired products
        
        Priority order:
        1. Unfrozen (descongelado) - most urgent
        2. Expired or expiring soon
        3. Opened
        """
        today = date.today()
        limit_date = today + timedelta(days=days)

        # Get all non-frozen products within expiry window
        items = (
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
            .all()
        )
        
        # Sort with multi-level priority:
        # 1. By expiry date (expired/urgent/soon)
        # 2. By state within same expiry date (descongelado > abierto > cerrado)
        def sort_key(item):
            # Primary: expiry date (most urgent first)
            days_until_expiry = (item.fecha_caducidad - today).days
            
            # Secondary: state priority
            # 0 = descongelado (highest priority)
            # 1 = abierto (medium priority) 
            # 2 = cerrado (lowest priority)
            state_priority = {
                'descongelado': 0,
                'abierto': 1,
                'cerrado': 2
            }.get(item.estado_producto, 2)  # Default to cerrado priority
            
            return (days_until_expiry, state_priority)
        
        return sorted(items, key=sort_key)

    def get_stock_item_by_id_and_hogar(self, id_stock: int, hogar_id: int) -> InventoryStock | None:
        """Get stock item by ID within a household."""
        return self.db.query(InventoryStock).options(
            joinedload(InventoryStock.producto_maestro),
            joinedload(InventoryStock.ubicacion)
        ).filter(
            InventoryStock.id_stock == id_stock,
            InventoryStock.hogar_id == hogar_id
        ).first()

    def get_all_stock_for_hogar(self, hogar_id: int, search_term: str | None = None, status_filter: list[str] | None = None, sort_by: str | None = None) -> list[InventoryStock]:
        """
        Get all stock items for a household, with optional search, status filtering, and sorting.
        """
        query = (
            self.db.query(InventoryStock)
            .options(
                joinedload(InventoryStock.ubicacion)  # Keep joinedload for location
            )
            .join(Product)  # Explicit JOIN with Product
            .filter(InventoryStock.hogar_id == hogar_id)
        )

        # 1. Unified Search (Name, Brand, Barcode)
        if search_term:
            search = f"%{search_term.lower()}%"
            query = query.filter(
                (Product.nombre.ilike(search)) |
                (Product.marca.ilike(search)) |
                (Product.barcode.ilike(search))
            )

        # 2. Status Filtering (AND Logic)
        if status_filter and len(status_filter) > 0:
            today = date.today()
            
            for status in status_filter:
                if status == 'congelado':
                    query = query.filter(InventoryStock.estado_producto == 'congelado')
                elif status == 'abierto':
                    query = query.filter(InventoryStock.estado_producto == 'abierto')
                elif status == 'urgente':
                    # Red: 0 <= days <= 5. Exclude frozen.
                    limit_date = today + timedelta(days=5)
                    query = query.filter(
                        and_(
                            InventoryStock.estado_producto != 'congelado',
                            InventoryStock.fecha_caducidad >= today,
                            InventoryStock.fecha_caducidad <= limit_date
                        )
                    )
                elif status == 'por_caducar':
                    # Yellow: 5 < days <= 10. Exclude frozen.
                    start_date = today + timedelta(days=5)
                    end_date = today + timedelta(days=10)
                    query = query.filter(
                        and_(
                            InventoryStock.estado_producto != 'congelado',
                            InventoryStock.fecha_caducidad > start_date,
                            InventoryStock.fecha_caducidad <= end_date
                        )
                    )
                elif status == 'caducado':
                    # Expired: date < today. Exclude frozen.
                    query = query.filter(
                        and_(
                            InventoryStock.estado_producto != 'congelado',
                            InventoryStock.fecha_caducidad < today
                        )
                    )

        # 3. Sorting
        if sort_by:
            if sort_by == 'expiry_asc':
                query = query.order_by(InventoryStock.fecha_caducidad.asc())
            elif sort_by == 'expiry_desc':
                query = query.order_by(InventoryStock.fecha_caducidad.desc())
            elif sort_by == 'name_asc':
                query = query.order_by(Product.nombre.asc())
            elif sort_by == 'name_desc':
                query = query.order_by(Product.nombre.desc())
            elif sort_by == 'quantity_asc':
                query = query.order_by(InventoryStock.cantidad_actual.asc())
            elif sort_by == 'quantity_desc':
                query = query.order_by(InventoryStock.cantidad_actual.desc())
            else:
                # Default sort
                query = query.order_by(Product.nombre, InventoryStock.fecha_caducidad)
        else:
            # Default sort
            query = query.order_by(Product.nombre, InventoryStock.fecha_caducidad)

        return query.all()

    def delete_stock_item(self, item: InventoryStock):
        """Delete a stock item."""
        self.db.delete(item)
        self.db.commit()
    
    def update_stock_item(self, item: InventoryStock):
        """Update a stock item."""
        self.db.commit()
        self.db.refresh(item)
        return item

    def get_product_suggestions(self, hogar_id: int, product_ids: list[int]) -> dict[int, int]:
        """
        Get suggested locations for a list of products.
        Returns: {product_id: location_id}
        Logic:
        1. Check active stock (where is it now?).
        2. If no stock, check last_location_id (where was it last?).
        """
        suggestions = {}
        
        # 1. Check active stock
        active_stock = (
            self.db.query(InventoryStock)
            .filter(
                InventoryStock.hogar_id == hogar_id,
                InventoryStock.fk_producto_maestro.in_(product_ids),
                InventoryStock.cantidad_actual > 0
            )
            .all()
        )
        
        for item in active_stock:
            # If multiple locations, just pick the first one found (simplification)
            if item.fk_producto_maestro not in suggestions:
                suggestions[item.fk_producto_maestro] = item.fk_ubicacion
        
        # 2. Check memory (last_location_id) for items not yet found
        remaining_ids = [pid for pid in product_ids if pid not in suggestions]
        if remaining_ids:
            products = (
                self.db.query(Product)
                .filter(
                    Product.id_producto.in_(remaining_ids),
                    Product.hogar_id == hogar_id,
                    Product.last_location_id.isnot(None)
                )
                .all()
            )
            for prod in products:
                suggestions[prod.id_producto] = prod.last_location_id
                
        return suggestions