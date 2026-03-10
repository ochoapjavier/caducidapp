from pydantic import BaseModel
from typing import List

class TicketParsedItem(BaseModel):
    nombre: str
    precioUnitario: float
    cantidad: int
    eansAsignados: List[str] = []

class SupermercadoCreate(BaseModel):
    nombre: str
    logo_url: str | None = None
    color_hex: str | None = None

class SupermercadoSchema(BaseModel):
    id_supermercado: int
    nombre: str
    logo_url: str | None = None
    color_hex: str | None = None

    class Config:
        from_attributes = True

class TicketMatchRequest(BaseModel):
    items: List[TicketParsedItem]
    ubicacion_id: int | None = None
    supermercado_id: int | None = None
    supermercado_nombre: str = "Desconocido"
    # For now we won't strictly enforce an insertion into inventory,
    # but we will save the dictionary matches.
