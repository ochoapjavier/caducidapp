"""Router for supermarket catalog operations."""
from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database import get_db
from models import Supermercado
from schemas import SupermercadoSchema, SupermercadoCreate
from auth.firebase_auth import get_current_user_id

router = APIRouter()


@router.get("/", response_model=List[SupermercadoSchema])
def get_supermercados(
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """
    Returns the global list of Supermarkets to display in the frontend Matchmaker Dropdown.
    Requires an authenticated user session.
    """
    supermercados = db.query(Supermercado).order_by(Supermercado.nombre).all()
    return supermercados


@router.post("/", response_model=SupermercadoSchema, status_code=status.HTTP_201_CREATED)
def create_supermercado(
    request: SupermercadoCreate,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """
    Allows an authenticated user to create a new Supermarket if it is not in the global list.
    Idempotent: if a supermarket with the same uppercase name already exists, returns it.
    """
    nombre_upper = request.nombre.strip().upper()

    # Check if exists (case-insensitive)
    existe = db.query(Supermercado).filter(Supermercado.nombre.ilike(nombre_upper)).first()
    if existe:
        return existe

    nuevo = Supermercado(
        nombre=nombre_upper,
        logo_url=request.logo_url,
        color_hex=request.color_hex or "#808080",
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)

    return nuevo
