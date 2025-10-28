# backend/services/alerta_service.py
from sqlalchemy.orm import Session
from datetime import date
from repositories import StockRepository
from schemas import AlertaResponse, ItemStock

class AlertaService:
    def __init__(self, db: Session):
        self.repo = StockRepository(db)

    def get_expiring_alerts(self, days: int = 7) -> AlertaResponse:
        items_raw = self.repo.get_alertas_caducidad(days)
        
        items_stock = [
            ItemStock(
                producto=item['producto'],
                cantidad=item['cantidad'],
                fecha_caducidad=date.fromisoformat(item['fecha_caducidad']),
                ubicacion=item['ubicacion']
            ) for item in items_raw
        ]

        return AlertaResponse(productos_proximos_a_caducar=items_stock)
