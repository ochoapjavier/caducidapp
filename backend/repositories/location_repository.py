# backend/repositories/location_repository.py
from sqlalchemy.orm import Session
from models import Location, InventoryStock


class LocationRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_location_by_id_and_user(self, id_ubicacion: int, user_id: str) -> Location | None:
        return (
            self.db.query(Location)
            .filter(Location.id_ubicacion == id_ubicacion, Location.user_id == user_id)
            .first()
        )

    def get_location_by_name_and_user(self, nombre: str, user_id: str) -> Location | None:
        return (
            self.db.query(Location)
            .filter(Location.nombre == nombre, Location.user_id == user_id)
            .first()
        )

    def get_all_locations_for_user(self, user_id: str) -> list[Location]:
        return (
            self.db.query(Location)
            .filter(Location.user_id == user_id)
            .order_by(Location.nombre)
            .all()
        )

    def create_location(self, nombre: str, user_id: str, es_congelador: bool = False) -> Location:
        new_location = Location(nombre=nombre, user_id=user_id, es_congelador=es_congelador)
        self.db.add(new_location)
        self.db.commit()
        self.db.refresh(new_location)
        return new_location

    def delete_location(self, location: Location):
        self.db.delete(location)
        self.db.commit()

    def update_location(self, location: Location, new_name: str, es_congelador: bool = None) -> Location:
        location.nombre = new_name
        if es_congelador is not None:
            location.es_congelador = es_congelador
        self.db.commit()
        self.db.refresh(location)
        return location

    def is_location_in_use_by_user(self, id_ubicacion: int, user_id: str) -> bool:
        return (
            self.db.query(InventoryStock)
            .filter(
                InventoryStock.fk_ubicacion == id_ubicacion,
                InventoryStock.user_id == user_id,
            )
            .first()
            is not None
        )
