# backend/routers/stock.py
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from schemas import (
    StockItem, StockItemCreate, StockItemCreateFromScan,
    StockUpdate, StockRemove,
)
from services.stock_service import StockService
from auth.firebase_auth import get_current_user_id

router = APIRouter()

def get_stock_service(db: Session = Depends(get_db)):
    return StockService(db)

@router.post("/manual", response_model=StockItem, status_code=status.HTTP_201_CREATED)
def add_manual_stock_endpoint(
    data: StockItemCreate, 
    service: StockService = Depends(get_stock_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.process_manual_stock(data, user_id)

@router.post("/from-scan", response_model=StockItem, status_code=status.HTTP_201_CREATED)
def add_scan_stock_endpoint(
    data: StockItemCreateFromScan, 
    service: StockService = Depends(get_stock_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.process_scan_stock(data, user_id)

@router.get("/", response_model=List[StockItem])
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

@router.post("/remove", status_code=200)
def remove_stock_items(
    payload: StockRemove,
    service: StockService = Depends(get_stock_service),
    user_id: str = Depends(get_current_user_id)
):
    """Elimina una cantidad específica de un item de stock."""
    return service.remove_stock_quantity(payload.id_stock, payload.cantidad, user_id)

@router.patch("/{id_stock}", response_model=StockItem, status_code=200)
def update_stock_item(
    id_stock: int,
    payload: StockUpdate,
    service: StockService = Depends(get_stock_service),
    user_id: str = Depends(get_current_user_id)
):
    """Actualiza campos editables de un item de stock: nombre/marca (producto maestro), fecha de caducidad, cantidad y ubicación."""
    return service.update_stock_item_details(id_stock, user_id, payload)