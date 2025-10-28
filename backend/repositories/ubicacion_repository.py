# backend/repositories/ubicacion_repository.py
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List, Optional

class UbicacionRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_ubicacion(self, nombre: str) -> int:
        params = {"nombre": nombre}
        query = text("INSERT INTO Ubicacion (nombre) VALUES (:nombre) RETURNING id_ubicacion")
        result = self.db.execute(query, params=params)
        self.db.commit()
        return result.scalar_one()

    def get_ubicacion_id_by_name(self, nombre: str) -> Optional[int]:
        query = text("SELECT id_ubicacion FROM Ubicacion WHERE nombre = :nombre")
        return self.db.execute(query, {"nombre": nombre}).scalar_one_or_none()

    def get_all_ubicaciones(self) -> List[dict]:
        query = text("SELECT id_ubicacion, nombre FROM Ubicacion ORDER BY nombre")
        ubicaciones = self.db.execute(query).fetchall()
        return [{"id_ubicacion": row[0], "nombre": row[1]} for row in ubicaciones]

    def is_ubicacion_in_use(self, id_ubicacion: int) -> bool:
        query = text("SELECT 1 FROM InventarioStock WHERE fk_ubicacion = :id_ubicacion LIMIT 1")
        result = self.db.execute(query, {"id_ubicacion": id_ubicacion}).scalar_one_or_none()
        return result is not None

    def delete_ubicacion_by_id(self, id_ubicacion: int) -> int:
        check_query = text("SELECT id_ubicacion FROM Ubicacion WHERE id_ubicacion = :id_ubicacion")
        ubicacion_exists = self.db.execute(check_query, {"id_ubicacion": id_ubicacion}).scalar_one_or_none()

        if ubicacion_exists is None:
            return 0

        delete_query = text("DELETE FROM Ubicacion WHERE id_ubicacion = :id_ubicacion")
        result = self.db.execute(delete_query, {"id_ubicacion": id_ubicacion})
        self.db.commit()
        return result.rowcount

    def update_ubicacion_by_id(self, id_ubicacion: int, new_name: str) -> int:
        query = text("UPDATE Ubicacion SET nombre = :new_name WHERE id_ubicacion = :id_ubicacion")
        result = self.db.execute(query, {"new_name": new_name, "id_ubicacion": id_ubicacion})
        self.db.commit()
        return result.rowcount
