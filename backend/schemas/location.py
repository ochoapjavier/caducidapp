# backend/schemas/location.py
from pydantic import BaseModel


class LocationBase(BaseModel):
    nombre: str
    es_congelador: bool = False


class LocationCreate(LocationBase):
    pass


class Location(LocationBase):
    id_ubicacion: int

    class Config:
        from_attributes = True
