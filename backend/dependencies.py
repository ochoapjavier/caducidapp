# backend/dependencies.py
"""FastAPI dependencies for authentication and authorization."""

from fastapi import Header, HTTPException, Depends, status
from sqlalchemy.orm import Session
from typing import Tuple

from auth.firebase_auth import get_current_user_id
from database import get_db
from repositories.hogar_repository import HogarRepository


async def get_active_hogar_id(
    x_hogar_id: int | None = Header(None, alias="X-Hogar-Id", description="Active household ID (optional - uses first household if not provided)"),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
) -> int:
    """
    Verify that the user has access to the requested household.
    
    This dependency:
    1. Reads the X-Hogar-Id header from the request (optional)
    2. If not provided, uses the user's first household
    3. Verifies the user is authenticated (via get_current_user_id)
    4. Checks that the user is a member of the household
    
    Args:
        x_hogar_id: Household ID from request header (optional)
        user_id: Authenticated user ID (from Firebase token)
        db: Database session
    
    Returns:
        The household ID if user has access
    
    Raises:
        HTTPException 403: If user is not a member of the household
        HTTPException 404: If user has no households
    """
    repo = HogarRepository(db)
    
    # If no hogar_id provided, use the first household the user belongs to
    if x_hogar_id is None:
        hogares = repo.get_hogares_by_user(user_id)
        if not hogares:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No tienes ningún hogar. Crea uno primero."
            )
        x_hogar_id = hogares[0].id_hogar
    
    # Check if user is a member of this household
    if not repo.user_is_member_of_hogar(user_id, x_hogar_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"No tienes acceso al hogar con ID {x_hogar_id}"
        )
    
    return x_hogar_id


async def require_admin_role(
    hogar_id: int = Depends(get_active_hogar_id),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
) -> Tuple[int, str]:
    """
    Verify that the user is an admin of the household.
    
    This dependency builds on get_active_hogar_id to additionally
    verify that the user has admin privileges.
    
    Use this for sensitive operations like:
    - Deleting the household
    - Removing members
    - Changing member roles
    - Regenerating invitation codes
    
    Args:
        hogar_id: Household ID (already verified by get_active_hogar_id)
        user_id: Authenticated user ID
        db: Database session
    
    Returns:
        Tuple of (hogar_id, user_id)
    
    Raises:
        HTTPException 403: If user is not an admin of the household
    """
    repo = HogarRepository(db)
    
    # Check if user is admin
    if not repo.user_is_admin_of_hogar(user_id, hogar_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los administradores pueden realizar esta acción"
        )
    
    return hogar_id, user_id


async def require_miembro_or_admin_role(
    hogar_id: int = Depends(get_active_hogar_id),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
) -> Tuple[int, str]:
    """
    Verify that the user is at least a 'miembro' (not just 'invitado').
    
    Use this for operations that require write access:
    - Adding products to inventory
    - Creating locations
    - Modifying stock
    
    'invitado' role typically has read-only access.
    
    Args:
        hogar_id: Household ID (already verified by get_active_hogar_id)
        user_id: Authenticated user ID
        db: Database session
    
    Returns:
        Tuple of (hogar_id, user_id)
    
    Raises:
        HTTPException 403: If user is only an 'invitado'
    """
    repo = HogarRepository(db)
    miembro = repo.get_miembro(user_id, hogar_id)
    
    # This should not happen as get_active_hogar_id already checked membership
    if not miembro:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No eres miembro de este hogar"
        )
    
    # Check role is not 'invitado'
    if miembro.rol == 'invitado':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Los invitados solo tienen acceso de lectura"
        )
    
    return hogar_id, user_id
