# backend/schemas/alerta.py
from pydantic import BaseModel
from typing import List
from .item import ItemStock

class AlertaResponse(BaseModel):
    productos_proximos_a_caducar: List[ItemStock]
