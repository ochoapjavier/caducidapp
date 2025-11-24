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
from dependencies import get_active_hogar_id, require_miembro_or_admin_role

router = APIRouter()

def get_stock_service(db: Session = Depends(get_db)):
    return StockService(db)

@router.post("/manual", response_model=StockItem, status_code=status.HTTP_201_CREATED)
def add_manual_stock_endpoint(
    data: StockItemCreate, 
    service: StockService = Depends(get_stock_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Add stock manually. Requires member or admin role."""
    hogar_id, user_id = auth_data
    return service.process_manual_stock(data, hogar_id, user_id)

@router.post("/from-scan", response_model=StockItem, status_code=status.HTTP_201_CREATED)
def add_scan_stock_endpoint(
    data: StockItemCreateFromScan, 
    service: StockService = Depends(get_stock_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Add stock from barcode scan. Requires member or admin role."""
    hogar_id, user_id = auth_data
    return service.process_scan_stock(data, hogar_id, user_id)

@router.get("/", response_model=List[StockItem])
def get_household_stock(
    search: str | None = None,
    service: StockService = Depends(get_stock_service),
    hogar_id: int = Depends(get_active_hogar_id)
):
    """
    Get all inventory for the household.
    Allows filtering by product name or barcode with the 'search' parameter.
    """
    return service.get_stock_for_hogar(hogar_id, search)

@router.patch("/{id_stock}/consume", status_code=200)
def consume_one_item(
    id_stock: int,
    service: StockService = Depends(get_stock_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Consume one unit of a stock item. If quantity reaches 0, the item is deleted. Requires member or admin role."""
    hogar_id, _ = auth_data
    return service.consume_stock_item(id_stock, hogar_id)

@router.post("/remove", status_code=200)
def remove_stock_items(
    payload: StockRemove,
    service: StockService = Depends(get_stock_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Remove a specific quantity from a stock item. Requires member or admin role."""
    hogar_id, _ = auth_data
    return service.remove_stock_quantity(payload.id_stock, payload.cantidad, hogar_id)

@router.patch("/{id_stock}", response_model=StockItem, status_code=200)
def update_stock_item(
    id_stock: int,
    payload: StockUpdate,
    service: StockService = Depends(get_stock_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Update editable fields of a stock item: name/brand (master product), expiration date, quantity and location. Requires member or admin role."""
    hogar_id, _ = auth_data
    return service.update_stock_item_details(id_stock, hogar_id, payload)