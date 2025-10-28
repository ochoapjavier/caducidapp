# backend/schemas/ubicacion.py
from pydantic import BaseModel

class UbicacionBase(BaseModel):
    nombre: str

class UbicacionCreate(UbicacionBase):
    pass

class Ubicacion(UbicacionBase):
    id_ubicacion: int

    class Config:
        from_attributes = True
