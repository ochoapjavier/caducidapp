from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models import Supermercado
from schemas import SupermercadoSchema, SupermercadoCreate

router = APIRouter()

@router.get("/", response_model=List[SupermercadoSchema])
def get_supermercados(db: Session = Depends(get_db)):
    """
    Returns the global list of Supermarkets to display in the frontend Matchmaker Dropdown.
    """
    supermercados = db.query(Supermercado).order_by(Supermercado.nombre).all()
    return supermercados

@router.post("/", response_model=SupermercadoSchema, status_code=status.HTTP_201_CREATED)
def create_supermercado(request: SupermercadoCreate, db: Session = Depends(get_db)):
    """
    Allows a user to manually create a new Supermarket if it's not in the global list.
    """
    nombre_upper = request.nombre.strip().upper()
    
    # Check if exists
    existe = db.query(Supermercado).filter(Supermercado.nombre.ilike(nombre_upper)).first()
    if existe:
        return existe # Idempotent

    nuevo = Supermercado(
        nombre=nombre_upper,
        logo_url=request.logo_url,
        color_hex=request.color_hex or '#808080'
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
    
    return nuevo
