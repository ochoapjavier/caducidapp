# backend/schemas/product_actions.py
"""
Schemas for product state management actions:
- Opening products
- Freezing products
- Unfreezing products
- Relocating products
"""
from pydantic import BaseModel, Field
from datetime import date
from typing import Optional


class OpenProductRequest(BaseModel):
    """Request to open a sealed product."""
    cantidad: int = Field(..., gt=0, description="Number of units to open")
    nueva_ubicacion_id: Optional[int] = Field(None, description="New location ID (optional)")
    mantener_fecha_caducidad: bool = Field(True, description="Keep original expiration date (True) or recalculate (False)")
    dias_vida_util: int = Field(4, ge=1, le=30, description="Shelf life days once opened (only used if mantener_fecha_caducidad=False)")

    class Config:
        json_schema_extra = {
            "example": {
                "cantidad": 1,
                "nueva_ubicacion_id": 2,
                "mantener_fecha_caducidad": True,
                "dias_vida_util": 4
            }
        }


class FreezeProductRequest(BaseModel):
    """Request to freeze a product to pause expiration."""
    cantidad: int = Field(..., gt=0, description="Number of units to freeze")
    ubicacion_congelador_id: int = Field(..., description="Freezer location ID")

    class Config:
        json_schema_extra = {
            "example": {
                "cantidad": 1,
                "ubicacion_congelador_id": 3
            }
        }


class UnfreezeProductRequest(BaseModel):
    """Request to unfreeze a product."""
    cantidad: int = Field(..., gt=0, description="Number of units to unfreeze")
    nueva_ubicacion_id: int = Field(..., description="New location ID (typically fridge)")
    dias_vida_util: int = Field(2, ge=1, le=7, description="Days to consume after unfreezing (default: 2)")

    class Config:
        json_schema_extra = {
            "example": {
                "cantidad": 1,
                "nueva_ubicacion_id": 2,
                "dias_vida_util": 2
            }
        }


class RelocateProductRequest(BaseModel):
    """Request to move product to different location."""
    cantidad: int = Field(..., gt=0, description="Number of units to move")
    nueva_ubicacion_id: int = Field(..., description="New location ID")

    class Config:
        json_schema_extra = {
            "example": {
                "cantidad": 2,
                "nueva_ubicacion_id": 4
            }
        }


class ProductActionResponse(BaseModel):
    """Generic response for product actions."""
    message: str
    item_original_id: Optional[int] = None
    item_nuevo_id: Optional[int] = None
    cantidad_procesada: int

    class Config:
        json_schema_extra = {
            "example": {
                "message": "Producto abierto exitosamente",
                "item_original_id": 15,
                "item_nuevo_id": 42,
                "cantidad_procesada": 1
            }
        }
