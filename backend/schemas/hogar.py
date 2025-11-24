# backend/schemas/hogar.py
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class HogarBase(BaseModel):
    """Base schema for household."""
    nombre: str = Field(..., min_length=1, max_length=200, description="Household name")
    icono: str = Field(default='home', max_length=50, description="Icon identifier")


class HogarCreate(HogarBase):
    """Schema for creating a new household."""
    pass


class HogarUpdate(BaseModel):
    """Schema for updating a household."""
    nombre: Optional[str] = Field(None, min_length=1, max_length=200)
    icono: Optional[str] = Field(None, max_length=50)


class MiembroInfo(BaseModel):
    """Schema for household member information."""
    user_id: str
    rol: str
    apodo: Optional[str] = None
    fecha_union: datetime
    
    class Config:
        from_attributes = True


class HogarSchema(HogarBase):
    """Complete household schema with all fields."""
    id_hogar: int
    created_by: str
    fecha_creacion: datetime
    codigo_invitacion: str
    miembros_count: int = Field(default=0, description="Number of members")
    mi_rol: Optional[str] = Field(None, description="Current user's role in this household")
    
    class Config:
        from_attributes = True


class HogarDetalle(HogarSchema):
    """Detailed household schema including members list."""
    miembros: list[MiembroInfo] = []
    
    class Config:
        from_attributes = True


class HogarMiembroBase(BaseModel):
    """Base schema for household membership."""
    fk_hogar: int
    user_id: str
    rol: str = Field(default='miembro', pattern='^(admin|miembro|invitado)$')
    apodo: Optional[str] = Field(None, max_length=100)


class HogarMiembroCreate(BaseModel):
    """Schema for adding a member to household (usually via invitation)."""
    codigo_invitacion: str = Field(..., min_length=8, max_length=8)
    apodo: Optional[str] = Field(None, max_length=100)


class HogarMiembroUpdate(BaseModel):
    """Schema for updating member information."""
    rol: Optional[str] = Field(None, pattern='^(admin|miembro|invitado)$')
    apodo: Optional[str] = Field(None, max_length=100)


class HogarMiembroSchema(HogarMiembroBase):
    """Complete member schema."""
    id_miembro: int
    fecha_union: datetime
    
    class Config:
        from_attributes = True


class InvitacionResponse(BaseModel):
    """Response when generating invitation code."""
    codigo_invitacion: str
    hogar_nombre: str
    expira_en: Optional[str] = Field(None, description="Optional expiration info")
