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

    def create_new_ubicacion(self, ubicacion_data: UbicacionCreate, user_id: str) -> Ubicacion:
        # Comprobamos si la ubicación ya existe PARA ESTE USUARIO
        existing_ubicacion = self.repo.get_ubicacion_by_name_and_user(ubicacion_data.nombre, user_id)
        if existing_ubicacion:
            raise HTTPException(status_code=409, detail=f"Ya tienes una ubicación llamada '{ubicacion_data.nombre}'.")
        
        try:
            # Pasamos el user_id al repositorio para la creación
            return self.repo.create_ubicacion(ubicacion_data.nombre, user_id)
        except IntegrityError:
             raise HTTPException(status_code=409, detail="Error de integridad, es posible que el nombre ya exista.")
        except Exception as e:
            # Log the exception e
            raise HTTPException(status_code=500, detail="Ocurrió un error interno al crear la ubicación.")

    def get_all_ubicaciones_for_user(self, user_id: str) -> list[Ubicacion]:
        # Pedimos al repositorio solo las ubicaciones de este usuario
        return self.repo.get_all_ubicaciones_for_user(user_id)

    def delete_ubicacion(self, id_ubicacion: int, user_id: str):
        # Buscamos la ubicación por su ID Y que pertenezca al usuario actual
        ubicacion = self.repo.get_ubicacion_by_id_and_user(id_ubicacion, user_id)
        if not ubicacion:
            raise HTTPException(
                status_code=404, 
                detail=f"Ubicación no encontrada o no tienes permiso para eliminarla."
            )

        # Comprobamos si la ubicación está en uso por ESTE usuario
        if self.repo.is_ubicacion_in_use_by_user(id_ubicacion, user_id):
            raise HTTPException(
                status_code=409,  # 409 Conflict
                detail="La ubicación no se puede eliminar porque contiene productos en tu inventario."
            )
        
        self.repo.delete_ubicacion(ubicacion)
            
        return {"status": "success", "message": "Ubicación eliminada correctamente."}

    def update_ubicacion(self, id_ubicacion: int, new_name: str, user_id: str) -> Ubicacion:
        # Buscamos la ubicación por su ID Y que pertenezca al usuario actual
        ubicacion_to_update = self.repo.get_ubicacion_by_id_and_user(id_ubicacion, user_id)
        if not ubicacion_to_update:
            raise HTTPException(
                status_code=404,
                detail=f"Ubicación no encontrada o no tienes permiso para actualizarla."
            )

        # Comprobamos si el nuevo nombre ya está en uso por OTRA ubicación DE ESTE MISMO USUARIO
        existing_ubicacion_with_new_name = self.repo.get_ubicacion_by_name_and_user(new_name, user_id)
        if existing_ubicacion_with_new_name and existing_ubicacion_with_new_name.id_ubicacion != id_ubicacion:
            raise HTTPException(
                status_code=409,  # Conflict
                detail=f"El nombre '{new_name}' ya está en uso por otra ubicación."
            )
        
        return self.repo.update_ubicacion(ubicacion_to_update, new_name)