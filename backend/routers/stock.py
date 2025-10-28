# backend/routers/stock.py
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from database import get_db
from schemas.item import ItemCreate, Item
from services.stock_service import StockService

router = APIRouter()

def get_stock_service(db: Session = Depends(get_db)):
    return StockService(db)

@router.post("/", response_model=Item, status_code=status.HTTP_201_CREATED)
def add_manual_stock_endpoint(
    data: ItemCreate,
    service: StockService = Depends(get_stock_service)
):
    return service.process_manual_stock(data)