# backend/routers/stock.py
from fastapi import APIRouter, Depends, status, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List
from database import get_db, Base
from schemas.item import Item, ItemCreate, ItemCreateFromScan
from services.stock_service import StockService
from auth.firebase_auth import get_current_user_id

router = APIRouter()

def get_stock_service(db: Session = Depends(get_db)):
    return StockService(db)

@router.post("/manual", response_model=Item, status_code=status.HTTP_201_CREATED)
def add_manual_stock_endpoint(
    data: ItemCreate, 
    service: StockService = Depends(get_stock_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.process_manual_stock(data, user_id)

@router.post("/from-scan", response_model=Item, status_code=status.HTTP_201_CREATED)
def add_scan_stock_endpoint(
    data: ItemCreateFromScan, 
    service: StockService = Depends(get_stock_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.process_scan_stock(data, user_id)

@router.get("/", response_model=List[Item])
def get_user_stock(
    search: str | None = None,
    service: StockService = Depends(get_stock_service),
    user_id: str = Depends(get_current_user_id)
):
    """
    Obtiene todo el inventario del usuario.
    Permite filtrar por nombre de producto o código de barras con el parámetro 'search'.
    """
    return service.get_stock_for_user(user_id, search)

@router.patch("/{id_stock}/consume", status_code=200)
def consume_one_item(
    id_stock: int,
    service: StockService = Depends(get_stock_service),
    user_id: str = Depends(get_current_user_id)
):
    """Consume una unidad de un item de stock. Si la cantidad llega a 0, el item es eliminado."""
    return service.consume_stock_item(id_stock, user_id)

class RemoveStockPayload(BaseModel):
    id_stock: int
    cantidad: int

@router.post("/remove", status_code=200)
def remove_stock_items(
    payload: RemoveStockPayload,
    service: StockService = Depends(get_stock_service),
    user_id: str = Depends(get_current_user_id)
):
    """Elimina una cantidad específica de un item de stock."""
    return service.remove_stock_quantity(payload.id_stock, payload.cantidad, user_id)