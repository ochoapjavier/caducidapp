# backend/routers/locations.py
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from schemas import LocationCreate, Location
from services.location_service import LocationService
from auth.firebase_auth import get_current_user_id

router = APIRouter()

def get_location_service(db: Session = Depends(get_db)):
    return LocationService(db)

@router.post("/", response_model=Location, status_code=status.HTTP_201_CREATED)
def create_location_endpoint(
    data: LocationCreate, 
    service: LocationService = Depends(get_location_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.create_new_ubicacion(data, user_id)

@router.get("/", response_model=List[Location])
def get_locations_endpoint(
    service: LocationService = Depends(get_location_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.get_all_ubicaciones_for_user(user_id)

@router.delete("/{id_ubicacion}", status_code=status.HTTP_200_OK)
def delete_location_endpoint(
    id_ubicacion: int,
    service: LocationService = Depends(get_location_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.delete_ubicacion(id_ubicacion, user_id)

@router.put("/{id_ubicacion}", response_model=Location, status_code=status.HTTP_200_OK)
def update_location_endpoint(
    id_ubicacion: int,
    ubicacion_data: LocationCreate,
    service: LocationService = Depends(get_location_service),
    user_id: str = Depends(get_current_user_id)
):
    return service.update_ubicacion(id_ubicacion, ubicacion_data.nombre, user_id)
