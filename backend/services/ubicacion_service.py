# backend/services/ubicacion_service.py
from fastapi import HTTPException
from sqlalchemy.orm import Session
from repositories import UbicacionRepository
from schemas import UbicacionCreate

class UbicacionService:
    def __init__(self, db: Session):
        self.repo = UbicacionRepository(db)

    def create_new_ubicacion(self, ubicacion_data: UbicacionCreate):
        try:
            ubicacion_id = self.repo.create_ubicacion(ubicacion_data.nombre)
            return {"id": ubicacion_id, "nombre": ubicacion_data.nombre}
        except Exception as e:
            raise HTTPException(status_code=400, detail="Error al crear ubicación. El nombre podría ser duplicado.")

    def get_all_ubicaciones(self):
        return self.repo.get_all_ubicaciones()

    def delete_ubicacion(self, id_ubicacion: int):
        if self.repo.is_ubicacion_in_use(id_ubicacion):
            raise HTTPException(
                status_code=409,  # 409 Conflict
                detail="La ubicación no se puede eliminar porque está en uso por uno o más productos en el inventario."
            )
        
        deleted_count = self.repo.delete_ubicacion_by_id(id_ubicacion)

        if deleted_count == 0:
            raise HTTPException(
                status_code=404, 
                detail=f"No se encontró una ubicación con el ID {id_ubicacion}."
            )
            
        return {"status": "success", "message": "Ubicación eliminada correctamente."}

    def update_ubicacion(self, id_ubicacion: int, new_name: str):
        existing_id = self.repo.get_ubicacion_id_by_name(new_name)
        if existing_id is not None and existing_id != id_ubicacion:
            raise HTTPException(
                status_code=409,  # Conflict
                detail=f"El nombre '{new_name}' ya está en uso por otra ubicación."
            )

        updated_count = self.repo.update_ubicacion_by_id(id_ubicacion, new_name)

        if updated_count == 0:
            raise HTTPException(
                status_code=404,
                detail=f"No se encontró una ubicación con el ID {id_ubicacion} para actualizar."
            )
            
        return {"status": "success", "message": "Ubicación actualizada correctamente."}
