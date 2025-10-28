# backend/schemas/item.py
from pydantic import BaseModel
from datetime import date
from .ubicacion import Ubicacion
from .producto import Producto

class ItemBase(BaseModel):
    nombre_producto: str
    cantidad: int
    fecha_caducidad: date

class ItemCreate(ItemBase):
    nombre_ubicacion: str

class Item(BaseModel):
    id_stock: int
    fk_producto_maestro: int
    fk_ubicacion: int
    cantidad_actual: int
    fecha_caducidad: date
    estado: str

    class Config:
        from_attributes = True

class ItemStock(BaseModel):
    cantidad_actual: int
    fecha_caducidad: date
    producto_obj: Producto
    ubicacion_obj: Ubicacion

    class Config:
        from_attributes = True