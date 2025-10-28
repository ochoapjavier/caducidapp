# backend/routers/ubicaciones.py
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from schemas.ubicacion import UbicacionCreate, Ubicacion
from services.ubicacion_service import UbicacionService

router = APIRouter()

def get_ubicacion_service(db: Session = Depends(get_db)):
    return UbicacionService(db)

@router.post("/", response_model=Ubicacion, status_code=status.HTTP_201_CREATED)
def create_ubicacion_endpoint(
    data: UbicacionCreate, 
    service: UbicacionService = Depends(get_ubicacion_service)
):
    return service.create_new_ubicacion(data)

@router.get("/", response_model=List[Ubicacion])
def get_ubicaciones_endpoint(
    service: UbicacionService = Depends(get_ubicacion_service)
):
    return service.get_all_ubicaciones()

@router.delete("/{id_ubicacion}", status_code=status.HTTP_200_OK)
def delete_ubicacion_endpoint(
    id_ubicacion: int,
    service: UbicacionService = Depends(get_ubicacion_service)
):
    return service.delete_ubicacion(id_ubicacion)

@router.put("/{id_ubicacion}", response_model=Ubicacion, status_code=status.HTTP_200_OK)
def update_ubicacion_endpoint(
    id_ubicacion: int,
    ubicacion_data: UbicacionCreate,
    service: UbicacionService = Depends(get_ubicacion_service)
):
    return service.update_ubicacion(id_ubicacion, ubicacion_data.nombre)