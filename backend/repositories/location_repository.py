# backend/repositories/location_repository.py
from sqlalchemy.orm import Session
from models import Location, InventoryStock


class LocationRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_location_by_id_and_hogar(self, id_ubicacion: int, hogar_id: int) -> Location | None:
        """Get location by ID within a specific household."""
        return (
            self.db.query(Location)
            .filter(Location.id_ubicacion == id_ubicacion, Location.hogar_id == hogar_id)
            .first()
        )

    def get_location_by_name_and_hogar(self, nombre: str, hogar_id: int) -> Location | None:
        """Get location by name within a specific household."""
        return (
            self.db.query(Location)
            .filter(Location.nombre == nombre, Location.hogar_id == hogar_id)
            .first()
        )

    def get_all_locations_for_hogar(self, hogar_id: int) -> list[Location]:
        """Get all locations for a household."""
        return (
            self.db.query(Location)
            .filter(Location.hogar_id == hogar_id)
            .order_by(Location.nombre)
            .all()
        )

    def create_location(self, nombre: str, hogar_id: int, es_congelador: bool = False) -> Location:
        """Create a new location in a household."""
        new_location = Location(nombre=nombre, hogar_id=hogar_id, es_congelador=es_congelador)
        self.db.add(new_location)
        self.db.commit()
        self.db.refresh(new_location)
        return new_location

    def delete_location(self, location: Location):
        """Delete a location."""
        self.db.delete(location)
        self.db.commit()

    def update_location(self, location: Location, new_name: str, es_congelador: bool = None) -> Location:
        """Update location information."""
        location.nombre = new_name
        if es_congelador is not None:
            location.es_congelador = es_congelador
        self.db.commit()
        self.db.refresh(location)
        return location

    def is_location_in_use_in_hogar(self, id_ubicacion: int, hogar_id: int) -> bool:
        """Check if location has any inventory items."""
        return (
            self.db.query(InventoryStock)
            .filter(
                InventoryStock.fk_ubicacion == id_ubicacion,
                InventoryStock.hogar_id == hogar_id,
            )
            .first()
            is not None
        )
