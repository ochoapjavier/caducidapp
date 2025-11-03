# backend/schemas/producto.py
from pydantic import BaseModel

class ProductoBase(BaseModel):
    nombre: str

class Producto(ProductoBase):
    id_producto: int

    class Config:
        from_attributes = True
