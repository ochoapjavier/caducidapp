# backend/routers/hogares.py
"""API endpoints for household management."""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from auth.firebase_auth import get_current_user_id
from dependencies import get_active_hogar_id, require_admin_role
from services.hogar_service import HogarService
from schemas.hogar import (
    HogarCreate, HogarUpdate, HogarSchema, HogarDetalle,
    HogarMiembroCreate, HogarMiembroUpdate, InvitacionResponse
)

router = APIRouter(prefix="/hogares", tags=["Hogares"])


@router.post("", response_model=HogarSchema, status_code=status.HTTP_201_CREATED)
def create_hogar(
    hogar_data: HogarCreate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Create a new household.
    
    The user creating the household automatically becomes an admin.
    """
    service = HogarService(db)
    return service.create_hogar(hogar_data, user_id)


@router.get("", response_model=List[HogarSchema])
def list_hogares(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Get all households where the current user is a member.
    
    Returns household information including the user's role in each.
    """
    service = HogarService(db)
    return service.get_hogares_usuario(user_id)


@router.get("/{hogar_id}", response_model=HogarDetalle)
async def get_hogar_detalle(
    hogar_id: int,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Get detailed information about a household.
    
    Requires: User must be a member of the household (checked by dependency).
    """
    # Verify access using await since get_active_hogar_id is async
    verified_hogar_id = await get_active_hogar_id(
        x_hogar_id=hogar_id,
        user_id=user_id,
        db=db
    )
    
    service = HogarService(db)
    return service.get_hogar_detalle(verified_hogar_id, user_id)


@router.put("/{hogar_id}", response_model=HogarSchema)
def update_hogar(
    hogar_id: int,
    hogar_data: HogarUpdate,
    auth_data: tuple = Depends(require_admin_role),
    db: Session = Depends(get_db)
):
    """
    Update household information (name, icon).
    
    Requires: Admin role.
    """
    verified_hogar_id, _ = auth_data
    service = HogarService(db)
    return service.update_hogar(verified_hogar_id, hogar_data)


@router.delete("/{hogar_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_hogar(
    hogar_id: int,
    auth_data: tuple = Depends(require_admin_role),
    db: Session = Depends(get_db)
):
    """
    Delete a household.
    
    This will cascade delete all locations, products, and inventory.
    
    Requires: Admin role.
    """
    verified_hogar_id, _ = auth_data
    service = HogarService(db)
    service.delete_hogar(verified_hogar_id)


@router.post("/unirse", response_model=HogarSchema)
def unirse_a_hogar(
    member_data: HogarMiembroCreate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Join a household using an invitation code.
    
    The user will be added as a 'miembro' (member) by default.
    """
    service = HogarService(db)
    return service.unirse_a_hogar(
        codigo=member_data.codigo_invitacion,
        user_id=user_id,
        apodo=member_data.apodo
    )


@router.post("/{hogar_id}/invitacion/regenerar", response_model=InvitacionResponse)
def regenerar_codigo_invitacion(
    hogar_id: int,
    auth_data: tuple = Depends(require_admin_role),
    db: Session = Depends(get_db)
):
    """
    Generate a new invitation code for the household.
    
    The old code will no longer work.
    
    Requires: Admin role.
    """
    verified_hogar_id, _ = auth_data
    service = HogarService(db)
    nuevo_codigo = service.regenerar_codigo_invitacion(verified_hogar_id)
    
    # Get hogar name for response
    from repositories.hogar_repository import HogarRepository
    repo = HogarRepository(db)
    hogar = repo.get_hogar_by_id(verified_hogar_id)
    
    return InvitacionResponse(
        codigo_invitacion=nuevo_codigo,
        hogar_nombre=hogar.nombre if hogar else ""
    )


@router.delete("/{hogar_id}/miembros/{user_id_to_remove}", status_code=status.HTTP_204_NO_CONTENT)
def expulsar_miembro(
    hogar_id: int,
    user_id_to_remove: str,
    auth_data: tuple = Depends(require_admin_role),
    db: Session = Depends(get_db)
):
    """
    Remove a member from the household.
    
    Cannot remove yourself (use abandonar endpoint).
    Cannot remove the last admin.
    
    Requires: Admin role.
    """
    verified_hogar_id, admin_user_id = auth_data
    service = HogarService(db)
    service.expulsar_miembro(verified_hogar_id, user_id_to_remove, admin_user_id)


@router.post("/{hogar_id}/abandonar", status_code=status.HTTP_204_NO_CONTENT)
def abandonar_hogar(
    hogar_id: int,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Leave a household.
    
    Cannot leave if you're the last admin. Assign another admin first or delete the household.
    
    Note: Uses hogar_id from path, not from X-Hogar-Id header.
    """
    service = HogarService(db)
    service.abandonar_hogar(hogar_id, user_id)


@router.put("/{hogar_id}/miembros/{user_id_target}/rol", status_code=status.HTTP_204_NO_CONTENT)
def cambiar_rol_miembro(
    hogar_id: int,
    user_id_target: str,
    member_data: HogarMiembroUpdate,
    auth_data: tuple = Depends(require_admin_role),
    db: Session = Depends(get_db)
):
    """
    Change a member's role in the household.
    
    Cannot demote the last admin.
    
    Requires: Admin role.
    """
    verified_hogar_id, _ = auth_data
    
    if not member_data.rol:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe especificar el nuevo rol"
        )
    
    service = HogarService(db)
    service.cambiar_rol_miembro(verified_hogar_id, user_id_target, member_data.rol)


@router.put("/{hogar_id}/miembros/mi-apodo", status_code=status.HTTP_204_NO_CONTENT)
def actualizar_mi_apodo(
    hogar_id: int,
    member_data: HogarMiembroUpdate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Update your own nickname in the household.
    
    Any member can update their own nickname.
    """
    if not member_data.apodo:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe especificar el nuevo apodo"
        )
    
    service = HogarService(db)
    service.actualizar_apodo_miembro(hogar_id, user_id, member_data.apodo)
