# backend/routers/alerts.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from schemas import AlertResponse
from services import AlertService
from dependencies import get_active_hogar_id

router = APIRouter()

def get_alert_service(db: Session = Depends(get_db)):
    return AlertService(db)

@router.get("/proxima-semana", response_model=AlertResponse)
def get_alerts_endpoint(
    service: AlertService = Depends(get_alert_service),
    hogar_id: int = Depends(get_active_hogar_id)
):
    """
    Get alerts for products expiring in the next 10 days or already expired.
    """
    return service.get_expiring_alerts_for_hogar(days=10, hogar_id=hogar_id)
