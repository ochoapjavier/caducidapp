# backend/repositories/ubicacion_repository.py
from sqlalchemy.orm import Session
from .models import Ubicacion, InventarioStock

class UbicacionRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_ubicacion_by_id_and_user(self, id_ubicacion: int, user_id: str) -> Ubicacion | None:
        return self.db.query(Ubicacion).filter(Ubicacion.id_ubicacion == id_ubicacion, Ubicacion.user_id == user_id).first()

    def get_ubicacion_by_name_and_user(self, nombre: str, user_id: str) -> Ubicacion | None:
        return self.db.query(Ubicacion).filter(Ubicacion.nombre == nombre, Ubicacion.user_id == user_id).first()

    def get_all_ubicaciones_for_user(self, user_id: str) -> list[Ubicacion]:
        return self.db.query(Ubicacion).filter(Ubicacion.user_id == user_id).order_by(Ubicacion.nombre).all()

    def create_ubicacion(self, nombre: str, user_id: str) -> Ubicacion:
        new_ubicacion = Ubicacion(nombre=nombre, user_id=user_id)
        self.db.add(new_ubicacion)
        self.db.commit()
        self.db.refresh(new_ubicacion)
        return new_ubicacion

    def delete_ubicacion(self, ubicacion: Ubicacion):
        self.db.delete(ubicacion)
        self.db.commit()

    def update_ubicacion(self, ubicacion: Ubicacion, new_name: str) -> Ubicacion:
        ubicacion.nombre = new_name
        self.db.commit()
        self.db.refresh(ubicacion)
        return ubicacion

    def is_ubicacion_in_use_by_user(self, id_ubicacion: int, user_id: str) -> bool:
        return self.db.query(InventarioStock).filter(
            InventarioStock.fk_ubicacion == id_ubicacion,
            InventarioStock.user_id == user_id
        ).first() is not None