# backend/repositories/models.py
from sqlalchemy import Column, Integer, String, Date, ForeignKey
from sqlalchemy.orm import relationship
from database import Base

class Ubicacion(Base):
    __tablename__ = "ubicacion"

    id_ubicacion = Column(Integer, primary_key=True, index=True)
    nombre = Column(String, unique=True, index=True, nullable=False)
    
    # Relación inversa
    items = relationship("InventarioStock", back_populates="ubicacion_obj") # Renombrado para evitar conflicto con el atributo 'ubicacion'

class ProductoMaestro(Base):
    __tablename__ = "producto_maestro"

    id_producto = Column(Integer, primary_key=True, index=True)
    nombre = Column(String, unique=True, index=True, nullable=False)

    # Relación inversa
    items = relationship("InventarioStock", back_populates="producto_obj") # Renombrado para evitar conflicto con el atributo 'producto'

class InventarioStock(Base):
    __tablename__ = "inventario_stock"

    id_stock = Column(Integer, primary_key=True, index=True)
    fk_producto_maestro = Column(Integer, ForeignKey("producto_maestro.id_producto"), nullable=False)
    fk_ubicacion = Column(Integer, ForeignKey("ubicacion.id_ubicacion"), nullable=False)
    cantidad_actual = Column(Integer, nullable=False)
    fecha_caducidad = Column(Date, nullable=False)
    estado = Column(String, default='Activo')

    # Relaciones para el ORM
    producto_obj = relationship("ProductoMaestro", back_populates="items") # Renombrado
    ubicacion_obj = relationship("Ubicacion", back_populates="items") # Renombrado