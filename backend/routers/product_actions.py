# backend/routers/product_actions.py
"""
Router for product state management actions.
Handles opening, freezing, unfreezing, and relocating products.
"""
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from database import get_db
from dependencies import require_miembro_or_admin_role
from services import ProductActionsService
from schemas import (
    OpenProductRequest,
    FreezeProductRequest,
    UnfreezeProductRequest,
    RelocateProductRequest,
    ProductActionResponse
)

router = APIRouter(prefix="/stock", tags=["Product Actions"])


def get_product_actions_service(db: Session = Depends(get_db)):
    return ProductActionsService(db)


@router.post(
    "/{stock_id}/open",
    response_model=ProductActionResponse,
    status_code=status.HTTP_200_OK,
    summary="Open sealed product units",
    description="""
    Opens sealed units of a product, creating a new item with:
    - State changed to 'abierto' (open)
    - Option to keep original expiration date or recalculate based on shelf life
    - Optionally moved to a new location (e.g., from pantry to fridge)
    
    The original item quantity is decremented accordingly.
    """
)
def open_product(
    stock_id: int,
    request: OpenProductRequest,
    service: ProductActionsService = Depends(get_product_actions_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Open sealed product units. Requires member or admin role."""
    hogar_id, user_id = auth_data
    return service.open_product(
        stock_id=stock_id,
        hogar_id=hogar_id,
        cantidad=request.cantidad,
        nueva_ubicacion_id=request.nueva_ubicacion_id,
        mantener_fecha_caducidad=request.mantener_fecha_caducidad,
        dias_vida_util=request.dias_vida_util
    )


@router.post(
    "/{stock_id}/freeze",
    response_model=ProductActionResponse,
    status_code=status.HTTP_200_OK,
    summary="Freeze product units",
    description="""
    Freezes units of a product to pause expiration, creating a new item with:
    - State changed to 'congelado' (frozen)
    - Expiration date paused (not counted in alerts)
    - Moved to freezer location
    
    Frozen products will not appear in expiration alerts.
    """
)
def freeze_product(
    stock_id: int,
    request: FreezeProductRequest,
    service: ProductActionsService = Depends(get_product_actions_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Freeze product units. Requires member or admin role."""
    hogar_id, user_id = auth_data
    return service.freeze_product(
        stock_id=stock_id,
        hogar_id=hogar_id,
        cantidad=request.cantidad,
        ubicacion_congelador_id=request.ubicacion_congelador_id
    )


@router.post(
    "/{stock_id}/unfreeze",
    response_model=ProductActionResponse,
    status_code=status.HTTP_200_OK,
    summary="Unfreeze product units",
    description="""
    Unfreezes units of a frozen product, creating a new item with:
    - State changed to 'descongelado' (unfrozen) - must be consumed quickly
    - New short expiration date (typically 1-2 days)
    - Moved to specified location (typically fridge)
    
    The frozen item quantity is decremented. If you unfreeze 1 of 3 units,
    2 remain frozen and 1 is unfrozen in the new location.
    
    ⚠️ Unfrozen products should be consumed quickly!
    """
)
def unfreeze_product(
    stock_id: int,
    request: UnfreezeProductRequest,
    service: ProductActionsService = Depends(get_product_actions_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Unfreeze product units. Requires member or admin role."""
    hogar_id, user_id = auth_data
    return service.unfreeze_product(
        stock_id=stock_id,
        hogar_id=hogar_id,
        cantidad=request.cantidad,
        nueva_ubicacion_id=request.nueva_ubicacion_id,
        dias_vida_util=request.dias_vida_util
    )


@router.post(
    "/{stock_id}/relocate",
    response_model=ProductActionResponse,
    status_code=status.HTTP_200_OK,
    summary="Relocate product to different location",
    description="""
    Moves product units to a different location without changing state or expiration.
    
    If an equivalent item (same product, expiration, state) exists in the target location,
    quantities will be merged. Otherwise, a new item is created.
    
    Note: For opened products that need new expiration, use the 'open' endpoint instead.
    """
)
def relocate_product(
    stock_id: int,
    request: RelocateProductRequest,
    service: ProductActionsService = Depends(get_product_actions_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Relocate product to different location. Requires member or admin role."""
    hogar_id, user_id = auth_data
    return service.relocate_product(
        stock_id=stock_id,
        hogar_id=hogar_id,
        cantidad=request.cantidad,
        nueva_ubicacion_id=request.nueva_ubicacion_id
    )
