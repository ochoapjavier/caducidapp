# backend/repositories/models.py
from sqlalchemy import Column, Integer, String, Date, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from database import Base

class Ubicacion(Base):
    __tablename__ = 'ubicacion'
    id_ubicacion = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    user_id = Column(String(255), nullable=False, index=True)
    __table_args__ = (UniqueConstraint('nombre', 'user_id', name='_nombre_user_uc'),)

class ProductoMaestro(Base):
    __tablename__ = 'producto_maestro'
    id_producto = Column(Integer, primary_key=True, index=True)
    # El barcode ya no es único globalmente, sino por usuario.
    barcode = Column(String(20), index=True, nullable=True)
    nombre = Column(String(255), nullable=False)
    marca = Column(String(100), nullable=True)
    image_url = Column(String(512), nullable=True) # <-- AÑADIR ESTA LÍNEA
    # AÑADIDO: La columna user_id que faltaba en el modelo.
    user_id = Column(String(255), nullable=False, index=True)

    # AÑADIDO: Restricción para que el barcode sea único por usuario.
    __table_args__ = (UniqueConstraint('barcode', 'user_id', name='_barcode_user_uc'),)
class InventarioStock(Base):
    __tablename__ = 'inventario_stock'
    id_stock = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(255), nullable=False, index=True)
    fk_producto_maestro = Column(Integer, ForeignKey('producto_maestro.id_producto'), nullable=False)
    fk_ubicacion = Column(Integer, ForeignKey('ubicacion.id_ubicacion'), nullable=False)
    cantidad_actual = Column(Integer, nullable=False)
    fecha_caducidad = Column(Date, nullable=False)
    estado = Column(String(50), default='Activo')

    # Relaciones para acceder a los objetos completos
    producto_maestro = relationship("ProductoMaestro")
    ubicacion = relationship("Ubicacion")