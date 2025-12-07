from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class ShoppingItemBase(BaseModel):
    producto_nombre: str
    cantidad: int = 1
    fk_producto: Optional[int] = None

class ShoppingItemCreate(ShoppingItemBase):
    pass

class ShoppingItemUpdate(BaseModel):
    cantidad: Optional[int] = None
    completado: Optional[bool] = None
    producto_nombre: Optional[str] = None

from schemas.item import ProductSchema

class ShoppingItemResponse(ShoppingItemBase):
    id: int
    hogar_id: int
    completado: bool
    added_by: str
    created_at: datetime
    updated_at: datetime
    producto: Optional[ProductSchema] = None

    class Config:
        from_attributes = True
