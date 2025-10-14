# backend/schemas/__init__.py

from pydantic import BaseModel
from datetime import date
from typing import List, Optional

# --- Modelos de Entrada (Para peticiones POST/PUT) ---
class UbicacionCreate(BaseModel):
    nombre: str

class ItemCreate(BaseModel):
    nombre_producto: str
    cantidad: int
    fecha_caducidad: date
    nombre_ubicacion: str

# --- Modelos de Salida (Para respuestas de la API) ---
class ItemStock(BaseModel):
    producto: str
    cantidad: int
    fecha_caducidad: date
    ubicacion: str

class AlertaResponse(BaseModel):
    productos_proximos_a_caducar: List