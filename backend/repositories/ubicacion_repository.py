# backend/repositories/ubicacion_repository.py
from sqlalchemy.orm import Session
from typing import List, Optional
from .models import Ubicacion, InventarioStock

class UbicacionRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_ubicacion(self, nombre: str) -> Ubicacion:
        nueva_ubicacion = Ubicacion(nombre=nombre)
        self.db.add(nueva_ubicacion)
        self.db.commit()
        self.db.refresh(nueva_ubicacion)
        return nueva_ubicacion

    def get_ubicacion_by_name(self, nombre: str) -> Optional[Ubicacion]:
        return self.db.query(Ubicacion).filter(Ubicacion.nombre == nombre).first()

    def get_ubicacion_by_id(self, id_ubicacion: int) -> Optional[Ubicacion]:
        return self.db.get(Ubicacion, id_ubicacion)

    def get_all_ubicaciones(self) -> List[Ubicacion]:
        return self.db.query(Ubicacion).order_by(Ubicacion.nombre).all()

    def is_ubicacion_in_use(self, id_ubicacion: int) -> bool:
        return self.db.query(InventarioStock).filter(InventarioStock.fk_ubicacion == id_ubicacion).first() is not None

    def delete_ubicacion(self, ubicacion: Ubicacion) -> None:
        self.db.delete(ubicacion)
        self.db.commit()

    def update_ubicacion(self, ubicacion: Ubicacion, new_name: str) -> Ubicacion:
        ubicacion.nombre = new_name
        self.db.commit()
        self.db.refresh(ubicacion)
        return ubicacion