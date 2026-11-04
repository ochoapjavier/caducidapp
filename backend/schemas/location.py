# backend/schemas/location.py
from pydantic import BaseModel, ConfigDict


class LocationBase(BaseModel):
    nombre: str
    es_congelador: bool = False


class LocationCreate(LocationBase):
    pass


class Location(LocationBase):
    id_ubicacion: int

    model_config = ConfigDict(from_attributes=True)
