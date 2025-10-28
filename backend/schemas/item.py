# backend/schemas/item.py
from pydantic import BaseModel
from datetime import date

class ItemBase(BaseModel):
    nombre_producto: str
    cantidad: int
    fecha_caducidad: date

class ItemCreate(ItemBase):
    nombre_ubicacion: str

class ItemStock(BaseModel):
    producto: str
    cantidad: int
    fecha_caducidad: date
    ubicacion: str
