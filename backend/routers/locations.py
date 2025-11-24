# backend/routers/locations.py
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from schemas import LocationCreate, Location
from services.location_service import LocationService
from dependencies import get_active_hogar_id, require_miembro_or_admin_role

router = APIRouter()

def get_location_service(db: Session = Depends(get_db)):
    return LocationService(db)

@router.post("/", response_model=Location, status_code=status.HTTP_201_CREATED)
def create_location_endpoint(
    data: LocationCreate, 
    service: LocationService = Depends(get_location_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Create a new location in the household. Requires member or admin role."""
    hogar_id, _ = auth_data
    return service.create_new_ubicacion(data, hogar_id)

@router.get("/", response_model=List[Location])
def get_locations_endpoint(
    service: LocationService = Depends(get_location_service),
    hogar_id: int = Depends(get_active_hogar_id)
):
    """Get all locations for the household."""
    return service.get_all_ubicaciones_for_hogar(hogar_id)

@router.delete("/{id_ubicacion}", status_code=status.HTTP_200_OK)
def delete_location_endpoint(
    id_ubicacion: int,
    service: LocationService = Depends(get_location_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Delete a location from the household. Requires member or admin role."""
    hogar_id, _ = auth_data
    return service.delete_ubicacion(id_ubicacion, hogar_id)

@router.put("/{id_ubicacion}", response_model=Location, status_code=status.HTTP_200_OK)
def update_location_endpoint(
    id_ubicacion: int,
    ubicacion_data: LocationCreate,
    service: LocationService = Depends(get_location_service),
    auth_data: tuple = Depends(require_miembro_or_admin_role)
):
    """Update a location in the household. Requires member or admin role."""
    hogar_id, _ = auth_data
    return service.update_ubicacion(
        id_ubicacion, 
        ubicacion_data.nombre, 
        hogar_id,
        es_congelador=ubicacion_data.es_congelador
    )
