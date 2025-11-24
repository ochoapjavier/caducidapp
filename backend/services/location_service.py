# backend/services/location_service.py
from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from repositories.location_repository import LocationRepository
from schemas import LocationCreate
from models import Location

class LocationService:
    def __init__(self, db: Session):
        self.repo = LocationRepository(db)

    def create_new_ubicacion(self, ubicacion_data: LocationCreate, hogar_id: int) -> Location:
        """Create a new location in a household."""
        # Idempotent check per household
        existing_location = self.repo.get_location_by_name_and_hogar(ubicacion_data.nombre, hogar_id)
        if existing_location:
            raise HTTPException(status_code=409, detail=f"Ya existe una ubicación llamada '{ubicacion_data.nombre}' en este hogar.")
        try:
            return self.repo.create_location(
                ubicacion_data.nombre, 
                hogar_id, 
                es_congelador=ubicacion_data.es_congelador
            )
        except IntegrityError:
            raise HTTPException(status_code=409, detail="Error de integridad, es posible que el nombre ya exista.")
        except Exception:
            raise HTTPException(status_code=500, detail="Ocurrió un error interno al crear la ubicación.")

    def get_all_ubicaciones_for_hogar(self, hogar_id: int) -> list[Location]:
        """Get all locations for a household."""
        return self.repo.get_all_locations_for_hogar(hogar_id)

    def delete_ubicacion(self, id_ubicacion: int, hogar_id: int):
        """Delete a location from a household."""
        location = self.repo.get_location_by_id_and_hogar(id_ubicacion, hogar_id)
        if not location:
            raise HTTPException(status_code=404, detail="Ubicación no encontrada o no pertenece a este hogar.")
        if self.repo.is_location_in_use_in_hogar(id_ubicacion, hogar_id):
            raise HTTPException(status_code=409, detail="La ubicación no se puede eliminar porque contiene productos en el inventario.")
        self.repo.delete_location(location)
        return {"status": "success", "message": "Ubicación eliminada correctamente."}

    def update_ubicacion(self, id_ubicacion: int, new_name: str, hogar_id: int, es_congelador: bool = None) -> Location:
        """Update a location in a household."""
        location_to_update = self.repo.get_location_by_id_and_hogar(id_ubicacion, hogar_id)
        if not location_to_update:
            raise HTTPException(status_code=404, detail="Ubicación no encontrada o no pertenece a este hogar.")
        existing_with_new_name = self.repo.get_location_by_name_and_hogar(new_name, hogar_id)
        if existing_with_new_name and existing_with_new_name.id_ubicacion != id_ubicacion:
            raise HTTPException(status_code=409, detail=f"El nombre '{new_name}' ya está en uso por otra ubicación en este hogar.")
        return self.repo.update_location(location_to_update, new_name, es_congelador=es_congelador)
