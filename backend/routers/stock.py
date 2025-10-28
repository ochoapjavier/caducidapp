# backend/routers/stock.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from schemas import ItemCreate
from services import StockService

router = APIRouter()

def get_stock_service(db: Session = Depends(get_db)):
    return StockService(db)

@router.post("/inventario/")
def add_manual_stock_endpoint(
    data: ItemCreate,
    service: StockService = Depends(get_stock_service)
):
    return service.process_manual_stock(data)
