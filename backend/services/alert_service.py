# backend/services/alert_service.py
from sqlalchemy.orm import Session
from repositories.stock_repository import StockRepository
from schemas.alert import AlertResponse

class AlertService:
    def __init__(self, db: Session):
        self.repo = StockRepository(db)

    def get_expiring_alerts_for_user(self, days: int, user_id: str) -> AlertResponse:
        items = self.repo.get_alertas_caducidad_for_user(days, user_id)
        return AlertResponse(productos_proximos_a_caducar=items)
