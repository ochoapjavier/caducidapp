# backend/models.py
from sqlalchemy import Column, Integer, String, Date, ForeignKey, UniqueConstraint, Index, Boolean
from sqlalchemy.orm import relationship
from database import Base

class Location(Base):
    """Physical or logical place where products are stored.

    Name is unique per user to allow the same names across users without collision.
    """
    __tablename__ = 'ubicacion'
    id_ubicacion = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    user_id = Column(String(255), nullable=False, index=True)
    es_congelador = Column(Boolean, nullable=False, default=False)  # Indicates if location is a freezer
    __table_args__ = (
        UniqueConstraint('nombre', 'user_id', name='_nombre_user_uc'),
    )

    # Back relation: a location can have many stock items
    stock_items = relationship(
        "InventoryStock",
        back_populates="ubicacion",
        cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"Location(id={self.id_ubicacion}, nombre={self.nombre!r}, user_id={self.user_id})"


class Product(Base):
    """User's product catalog.

    (barcode, user_id) is unique so different users can have the same barcode.
    If a product has no barcode, we disambiguate by (user_id, nombre) at repository level.
    """
    __tablename__ = 'producto_maestro'
    id_producto = Column(Integer, primary_key=True, index=True)
    barcode = Column(String(20), index=True, nullable=True)
    nombre = Column(String(255), nullable=False, index=True)
    marca = Column(String(100), nullable=True)
    image_url = Column(String(512), nullable=True)
    user_id = Column(String(255), nullable=False, index=True)
    __table_args__ = (
        UniqueConstraint('barcode', 'user_id', name='_barcode_user_uc'),
        Index('ix_producto_user_nombre', 'user_id', 'nombre'),
    )

    stock_items = relationship(
        "InventoryStock",
        back_populates="producto_maestro",
        cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"Product(id={self.id_producto}, nombre={self.nombre!r}, barcode={self.barcode!r}, user_id={self.user_id})"


class InventoryStock(Base):
    """Units of a product in a specific location.

    Grouped by (product, location, expiration_date).
    Now supports product states: closed (sealed), open, frozen.
    """
    __tablename__ = 'inventario_stock'
    id_stock = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(255), nullable=False, index=True)
    fk_producto_maestro = Column(Integer, ForeignKey('producto_maestro.id_producto'), nullable=False)
    fk_ubicacion = Column(Integer, ForeignKey('ubicacion.id_ubicacion'), nullable=False)
    cantidad_actual = Column(Integer, nullable=False)
    fecha_caducidad = Column(Date, nullable=False, index=True)
    estado = Column(String(50), default='Activo')  # Legacy field, kept for compatibility
    
    # New fields for product state management
    estado_producto = Column(String(20), default='cerrado', nullable=False)  # 'cerrado', 'abierto', 'congelado'
    fecha_apertura = Column(Date, nullable=True)  # Date when product was opened
    fecha_congelacion = Column(Date, nullable=True)  # Date when product was frozen
    dias_caducidad_abierto = Column(Integer, nullable=True)  # Shelf life days once opened
    
    __table_args__ = (
        Index('ix_stock_user_fecha', 'user_id', 'fecha_caducidad'),
        Index('ix_inventario_stock_estado', 'estado_producto'),
    )

    # Keep attribute names to match existing API schemas (producto_maestro, ubicacion)
    producto_maestro = relationship("Product", back_populates="stock_items")
    ubicacion = relationship("Location", back_populates="stock_items")

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"InventoryStock(id={self.id_stock}, producto={self.fk_producto_maestro}, "
            f"ubicacion={self.fk_ubicacion}, cantidad={self.cantidad_actual}, fecha={self.fecha_caducidad})"
        )
