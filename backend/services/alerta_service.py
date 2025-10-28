# backend/services/alerta_service.py
from sqlalchemy.orm import Session
from repositories.stock_repository import StockRepository
from schemas.alerta import AlertaResponse

class AlertaService:
    def __init__(self, db: Session):
        self.repo = StockRepository(db)

    def get_expiring_alerts(self, days: int = 7) -> AlertaResponse:
        items = self.repo.get_alertas_caducidad(days)
        return AlertaResponse(productos_proximos_a_caducar=items)