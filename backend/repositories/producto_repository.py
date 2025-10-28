# backend/repositories/producto_repository.py
from sqlalchemy.orm import Session
from sqlalchemy import text

class ProductoRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_or_create_producto_maestro(self, nombre: str) -> int:
        params = {"nombre": nombre}
        producto_id = self.db.execute(
            text("SELECT id_producto FROM ProductoMaestro WHERE nombre = :nombre"),
            params=params
        ).scalar_one_or_none()
        
        if producto_id is None:
            result = self.db.execute(
                text("INSERT INTO ProductoMaestro (nombre) VALUES (:nombre) RETURNING id_producto"),
                params=params
            )
            producto_id = result.scalar_one()
            self.db.commit()
            
        return producto_id
