# backend/services/alert_service.py
from sqlalchemy.orm import Session
from repositories.stock_repository import StockRepository
from schemas.alert import AlertResponse

class AlertService:
    def __init__(self, db: Session):
        self.repo = StockRepository(db)

    def get_expiring_alerts_for_hogar(self, days: int, hogar_id: int) -> AlertResponse:
        """Get expiring alerts for a household."""
        items = self.repo.get_alertas_caducidad_for_hogar(days, hogar_id)
        return AlertResponse(productos_proximos_a_caducar=items)
