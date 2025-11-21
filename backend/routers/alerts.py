# backend/routers/alerts.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from schemas import AlertResponse
from services import AlertService
from auth.firebase_auth import get_current_user_id

router = APIRouter()

def get_alert_service(db: Session = Depends(get_db)):
    return AlertService(db)

@router.get("/proxima-semana", response_model=AlertResponse)
def get_alerts_endpoint(
    service: AlertService = Depends(get_alert_service),
    user_id: str = Depends(get_current_user_id)
):
    """
    Obtiene alertas de productos que caducan en los próximos 10 días
    o que ya están caducados.
    """
    return service.get_expiring_alerts_for_user(days=10, user_id=user_id)
