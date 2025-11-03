# backend/routers/ubicaciones.py
from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from schemas.ubicacion import UbicacionCreate, Ubicacion
from services.ubicacion_service import UbicacionService
from auth.firebase_auth import get_current_user_id

router = APIRouter()

def get_ubicacion_service(db: Session = Depends(get_db)):
    return UbicacionService(db)

@router.post("/", response_model=Ubicacion, status_code=status.HTTP_201_CREATED)
def create_ubicacion_endpoint(
    data: UbicacionCreate, 
    service: UbicacionService = Depends(get_ubicacion_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.create_new_ubicacion(data, user_id)

@router.get("/", response_model=List[Ubicacion])
def get_ubicaciones_endpoint(
    service: UbicacionService = Depends(get_ubicacion_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.get_all_ubicaciones_for_user(user_id)

@router.delete("/{id_ubicacion}", status_code=status.HTTP_200_OK)
def delete_ubicacion_endpoint(
    id_ubicacion: int,
    service: UbicacionService = Depends(get_ubicacion_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.delete_ubicacion(id_ubicacion, user_id)

@router.put("/{id_ubicacion}", response_model=Ubicacion, status_code=status.HTTP_200_OK)
def update_ubicacion_endpoint(
    id_ubicacion: int,
    ubicacion_data: UbicacionCreate,
    service: UbicacionService = Depends(get_ubicacion_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.update_ubicacion(id_ubicacion, ubicacion_data.nombre, user_id)