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

    def create_new_ubicacion(self, ubicacion_data: LocationCreate, user_id: str) -> Location:
        # Idempotent check per user
        existing_location = self.repo.get_location_by_name_and_user(ubicacion_data.nombre, user_id)
        if existing_location:
            raise HTTPException(status_code=409, detail=f"Ya tienes una ubicación llamada '{ubicacion_data.nombre}'.")
        try:
            return self.repo.create_location(ubicacion_data.nombre, user_id)
        except IntegrityError:
            raise HTTPException(status_code=409, detail="Error de integridad, es posible que el nombre ya exista.")
        except Exception:
            raise HTTPException(status_code=500, detail="Ocurrió un error interno al crear la ubicación.")

    def get_all_ubicaciones_for_user(self, user_id: str) -> list[Location]:
        return self.repo.get_all_locations_for_user(user_id)

    def delete_ubicacion(self, id_ubicacion: int, user_id: str):
        location = self.repo.get_location_by_id_and_user(id_ubicacion, user_id)
        if not location:
            raise HTTPException(status_code=404, detail="Ubicación no encontrada o no tienes permiso para eliminarla.")
        if self.repo.is_location_in_use_by_user(id_ubicacion, user_id):
            raise HTTPException(status_code=409, detail="La ubicación no se puede eliminar porque contiene productos en tu inventario.")
        self.repo.delete_location(location)
        return {"status": "success", "message": "Ubicación eliminada correctamente."}

    def update_ubicacion(self, id_ubicacion: int, new_name: str, user_id: str) -> Location:
        location_to_update = self.repo.get_location_by_id_and_user(id_ubicacion, user_id)
        if not location_to_update:
            raise HTTPException(status_code=404, detail="Ubicación no encontrada o no tienes permiso para actualizarla.")
        existing_with_new_name = self.repo.get_location_by_name_and_user(new_name, user_id)
        if existing_with_new_name and existing_with_new_name.id_ubicacion != id_ubicacion:
            raise HTTPException(status_code=409, detail=f"El nombre '{new_name}' ya está en uso por otra ubicación.")
        return self.repo.update_location(location_to_update, new_name)
