# backend/schemas/alert.py
from pydantic import BaseModel
from typing import List
from .item import StockAlertItem

class AlertResponse(BaseModel):
    productos_proximos_a_caducar: List[StockAlertItem] = []
