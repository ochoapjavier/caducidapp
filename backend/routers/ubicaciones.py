# backend/routers/ubicaciones.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from schemas import UbicacionCreate
from services import UbicacionService

router = APIRouter()

def get_ubicacion_service(db: Session = Depends(get_db)):
    return UbicacionService(db)

@router.post("/ubicaciones/")
def create_ubicacion_endpoint(
    data: UbicacionCreate, 
    service: UbicacionService = Depends(get_ubicacion_service)
):
    return service.create_new_ubicacion(data)

@router.get("/ubicaciones/")
def get_ubicaciones_endpoint(
    service: UbicacionService = Depends(get_ubicacion_service)
):
    return service.get_all_ubicaciones()

@router.delete("/ubicaciones/{id_ubicacion}", status_code=200)
def delete_ubicacion_endpoint(
    id_ubicacion: int,
    service: UbicacionService = Depends(get_ubicacion_service)
):
    return service.delete_ubicacion(id_ubicacion)

@router.put("/ubicaciones/{id_ubicacion}", status_code=200)
def update_ubicacion_endpoint(
    id_ubicacion: int,
    ubicacion_data: UbicacionCreate,
    service: UbicacionService = Depends(get_ubicacion_service)
):
    return service.update_ubicacion(id_ubicacion, ubicacion_data.nombre)
