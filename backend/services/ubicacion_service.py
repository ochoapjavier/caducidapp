# backend/services/ubicacion_service.py
from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from repositories.ubicacion_repository import UbicacionRepository
from schemas.ubicacion import UbicacionCreate
from repositories.models import Ubicacion

class UbicacionService:
    def __init__(self, db: Session):
        self.repo = UbicacionRepository(db)

    def create_new_ubicacion(self, ubicacion_data: UbicacionCreate) -> Ubicacion:
        existing_ubicacion = self.repo.get_ubicacion_by_name(ubicacion_data.nombre)
        if existing_ubicacion:
            raise HTTPException(status_code=409, detail="El nombre de la ubicación ya existe.")
        
        try:
            return self.repo.create_ubicacion(ubicacion_data.nombre)
        except IntegrityError:
             raise HTTPException(status_code=409, detail="Error de integridad, es posible que el nombre ya exista.")
        except Exception as e:
            # Log the exception e
            raise HTTPException(status_code=500, detail="Ocurrió un error interno al crear la ubicación.")

    def get_all_ubicaciones(self) -> list[Ubicacion]:
        return self.repo.get_all_ubicaciones()

    def delete_ubicacion(self, id_ubicacion: int):
        ubicacion = self.repo.get_ubicacion_by_id(id_ubicacion)
        if not ubicacion:
            raise HTTPException(
                status_code=4.04, 
                detail=f"No se encontró una ubicación con el ID {id_ubicacion}."
            )

        if self.repo.is_ubicacion_in_use(id_ubicacion):
            raise HTTPException(
                status_code=409,  # 409 Conflict
                detail="La ubicación no se puede eliminar porque está en uso."
            )
        
        self.repo.delete_ubicacion(ubicacion)
            
        return {"status": "success", "message": "Ubicación eliminada correctamente."}

    def update_ubicacion(self, id_ubicacion: int, new_name: str) -> Ubicacion:
        ubicacion_to_update = self.repo.get_ubicacion_by_id(id_ubicacion)
        if not ubicacion_to_update:
            raise HTTPException(
                status_code=404,
                detail=f"No se encontró una ubicación con el ID {id_ubicacion} para actualizar."
            )

        existing_ubicacion_with_new_name = self.repo.get_ubicacion_by_name(new_name)
        if existing_ubicacion_with_new_name and existing_ubicacion_with_new_name.id_ubicacion != id_ubicacion:
            raise HTTPException(
                status_code=409,  # Conflict
                detail=f"El nombre '{new_name}' ya está en uso por otra ubicación."
            )
        
        return self.repo.update_ubicacion(ubicacion_to_update, new_name)