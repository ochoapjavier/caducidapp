# backend/models.py
from sqlalchemy import Column, Integer, String, Date, ForeignKey, UniqueConstraint, Index, Boolean, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base


class Hogar(Base):
    """Household container for shared inventory management.
    
    Multiple users can be members of a household with different roles.
    A user can belong to multiple households.
    """
    __tablename__ = 'hogares'
    id_hogar = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(200), nullable=False)
    created_by = Column(String(255), nullable=False, index=True)  # Firebase UID of creator
    fecha_creacion = Column(DateTime, default=datetime.utcnow, nullable=False)
    icono = Column(String(50), default='home', nullable=False)  # Icon identifier
    codigo_invitacion = Column(String(8), unique=True, nullable=False, index=True)  # Invitation code
    
    # Relationships
    miembros = relationship("HogarMiembro", back_populates="hogar", cascade="all, delete-orphan")
    ubicaciones = relationship("Location", back_populates="hogar", cascade="all, delete-orphan")
    productos = relationship("Product", back_populates="hogar", cascade="all, delete-orphan")
    stock_items = relationship("InventoryStock", back_populates="hogar", cascade="all, delete-orphan")
    shopping_list_items = relationship("ShoppingListItem", back_populates="hogar", cascade="all, delete-orphan")
    
    def __repr__(self) -> str:  # pragma: no cover
        return f"Hogar(id={self.id_hogar}, nombre={self.nombre!r}, created_by={self.created_by})"


class HogarMiembro(Base):
    """User membership in a household with role-based permissions.
    
    Roles:
    - admin: Full control (manage household, invite/remove members, all inventory operations)
    - miembro: Can manage inventory, cannot manage household or members
    - invitado: Read-only access to inventory
    """
    __tablename__ = 'hogares_miembros'
    id_miembro = Column(Integer, primary_key=True, index=True)
    fk_hogar = Column(Integer, ForeignKey('hogares.id_hogar', ondelete='CASCADE'), nullable=False, index=True)
    user_id = Column(String(255), nullable=False, index=True)  # Firebase UID
    rol = Column(String(50), default='miembro', nullable=False, index=True)  # admin, miembro, invitado
    fecha_union = Column(DateTime, default=datetime.utcnow, nullable=False)
    apodo = Column(String(100), nullable=True)  # Friendly nickname within household
    
    __table_args__ = (
        UniqueConstraint('fk_hogar', 'user_id', name='hogar_miembro_unique'),
    )
    
    # Relationships
    hogar = relationship("Hogar", back_populates="miembros")
    
    def __repr__(self) -> str:  # pragma: no cover
        return f"HogarMiembro(hogar={self.fk_hogar}, user={self.user_id}, rol={self.rol!r})"

class Location(Base):
    """Physical or logical place where products are stored.

    Name is unique per household to allow the same names across households without collision.
    """
    __tablename__ = 'ubicacion'
    id_ubicacion = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    hogar_id = Column(Integer, ForeignKey('hogares.id_hogar', ondelete='CASCADE'), nullable=False, index=True)
    es_congelador = Column(Boolean, nullable=False, default=False)  # Indicates if location is a freezer
    __table_args__ = (
        UniqueConstraint('nombre', 'hogar_id', name='ubicacion_nombre_hogar_unique'),
    )

    # Relationships
    hogar = relationship("Hogar", back_populates="ubicaciones")
    stock_items = relationship(
        "InventoryStock",
        back_populates="ubicacion",
        cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"Location(id={self.id_ubicacion}, nombre={self.nombre!r}, hogar_id={self.hogar_id})"


class Product(Base):
    """Household's product catalog.

    (barcode, hogar_id) is unique so different households can have the same barcode.
    If a product has no barcode, we disambiguate by (hogar_id, nombre) at repository level.
    """
    __tablename__ = 'producto_maestro'
    id_producto = Column(Integer, primary_key=True, index=True)
    barcode = Column(String(20), index=True, nullable=True)
    nombre = Column(String(255), nullable=False, index=True)
    marca = Column(String(100), nullable=True)
    image_url = Column(String(512), nullable=True)
    dias_consumo_abierto = Column(Integer, nullable=True)  # Default days to consume after opening
    hogar_id = Column(Integer, ForeignKey('hogares.id_hogar', ondelete='CASCADE'), nullable=False, index=True)
    last_location_id = Column(Integer, ForeignKey('ubicacion.id_ubicacion', ondelete='SET NULL'), nullable=True)  # Smart Grouping Memory
    __table_args__ = (
        UniqueConstraint('barcode', 'hogar_id', name='producto_barcode_hogar_unique'),
        Index('ix_producto_hogar_nombre', 'hogar_id', 'nombre'),
    )

    # Relationships
    hogar = relationship("Hogar", back_populates="productos")
    stock_items = relationship(
        "InventoryStock",
        back_populates="producto_maestro",
        cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"Product(id={self.id_producto}, nombre={self.nombre!r}, barcode={self.barcode!r}, hogar_id={self.hogar_id})"


class InventoryStock(Base):
    """Units of a product in a specific location within a household.

    Grouped by (product, location, expiration_date).
    Now supports product states: closed (sealed), open, frozen.
    """
    __tablename__ = 'inventario_stock'
    id_stock = Column(Integer, primary_key=True, index=True)
    hogar_id = Column(Integer, ForeignKey('hogares.id_hogar', ondelete='CASCADE'), nullable=False, index=True)
    fk_producto_maestro = Column(Integer, ForeignKey('producto_maestro.id_producto'), nullable=False)
    fk_ubicacion = Column(Integer, ForeignKey('ubicacion.id_ubicacion'), nullable=False)
    cantidad_actual = Column(Integer, nullable=False)
    fecha_caducidad = Column(Date, nullable=False, index=True)
    estado = Column(String(50), default='Activo')  # Legacy field, kept for compatibility
    
    # New fields for product state management
    estado_producto = Column(String(20), default='cerrado', nullable=False)  # 'cerrado', 'abierto', 'congelado', 'descongelado'
    fecha_apertura = Column(Date, nullable=True)  # Date when product was opened
    fecha_congelacion = Column(Date, nullable=True)  # Date when product was frozen
    fecha_descongelacion = Column(Date, nullable=True)  # Date when frozen product was unfrozen
    dias_caducidad_abierto = Column(Integer, nullable=True)  # Shelf life days once opened
    
    __table_args__ = (
        Index('ix_stock_hogar_fecha', 'hogar_id', 'fecha_caducidad'),
        Index('ix_inventario_stock_estado', 'estado_producto'),
    )

    # Relationships
    hogar = relationship("Hogar", back_populates="stock_items")
    producto_maestro = relationship("Product", back_populates="stock_items")
    ubicacion = relationship("Location", back_populates="stock_items")

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"InventoryStock(id={self.id_stock}, hogar={self.hogar_id}, producto={self.fk_producto_maestro}, "
            f"ubicacion={self.fk_ubicacion}, cantidad={self.cantidad_actual}, fecha={self.fecha_caducidad})"
        )


class UserDevice(Base):
    """FCM tokens for user devices (mobile, web)."""
    __tablename__ = 'user_devices'
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(255), nullable=False, index=True)
    fcm_token = Column(String, nullable=False)
    platform = Column(String(50))  # android, web, ios
    last_active = Column(DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        UniqueConstraint('user_id', 'fcm_token', name='user_device_unique'),
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"UserDevice(user={self.user_id}, platform={self.platform})"


class UserPreference(Base):
    """User-specific notification settings."""
    __tablename__ = 'user_preferences'
    user_id = Column(String(255), primary_key=True)
    notifications_enabled = Column(Boolean, default=True)
    notification_time = Column(String(8), default='09:00:00')  # Stored as string HH:MM:SS for simplicity
    timezone_offset = Column(Integer, default=0)  # Offset in minutes

    def __repr__(self) -> str:  # pragma: no cover
        return f"UserPreference(user={self.user_id}, enabled={self.notifications_enabled})"


class ShoppingListItem(Base):
    """Item in the household shopping list."""
    __tablename__ = 'shopping_list_items'
    
    id = Column(Integer, primary_key=True, index=True)
    hogar_id = Column(Integer, ForeignKey('hogares.id_hogar', ondelete='CASCADE'), nullable=False, index=True)
    producto_nombre = Column(String(255), nullable=False)
    fk_producto = Column(Integer, ForeignKey('producto_maestro.id_producto', ondelete='SET NULL'), nullable=True)
    cantidad = Column(Integer, default=1, nullable=False)
    completado = Column(Boolean, default=False, nullable=False, index=True)
    added_by = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    hogar = relationship("Hogar", back_populates="shopping_list_items")
    producto = relationship("Product")

    def __repr__(self) -> str:  # pragma: no cover
        return f"ShoppingItem(id={self.id}, nombre={self.producto_nombre}, hogar={self.hogar_id})"
