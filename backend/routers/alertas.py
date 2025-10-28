# backend/routers/alertas.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from schemas import AlertaResponse
from services import AlertaService

router = APIRouter()

def get_alerta_service(db: Session = Depends(get_db)):
    return AlertaService(db)

@router.get("/proxima-semana", response_model=AlertaResponse)
def get_alertas_endpoint(
    service: AlertaService = Depends(get_alerta_service)
):
    return service.get_expiring_alerts(days=7)
