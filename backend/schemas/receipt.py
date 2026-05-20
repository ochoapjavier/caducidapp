from datetime import date

from pydantic import BaseModel, Field
from typing import List


class TicketAllocation(BaseModel):
    cantidad: int
    barcode: str | None = None
    product_name: str | None = None
    brand: str | None = None
    image_url: str | None = None
    ubicacion_id: int | None = None
    fecha_caducidad: date | None = None


class ReceiptDictionaryProductMatch(BaseModel):
    barcode: str
    product_name: str | None = None
    brand: str | None = None
    image_url: str | None = None

class TicketParsedItem(BaseModel):
    nombre: str
    precioUnitario: float
    cantidad: int
    eansAsignados: List[str] = Field(default_factory=list)
    ubicacion_id: int | None = None
    fecha_caducidad: date | None = None
    asignaciones: List[TicketAllocation] = Field(default_factory=list)


class ReceiptDictionaryEntry(BaseModel):
    supermercado_id: int
    ticket_nombre: str
    eans: List[str]
    matches: List[ReceiptDictionaryProductMatch]

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
