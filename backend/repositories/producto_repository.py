# backend/repositories/producto_repository.py
from sqlalchemy.orm import Session
from .models import ProductoMaestro

class ProductoRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_or_create_producto_maestro(self, nombre: str) -> ProductoMaestro:
        producto = self.db.query(ProductoMaestro).filter(ProductoMaestro.nombre == nombre).first()
        
        if not producto:
            producto = ProductoMaestro(nombre=nombre)
            self.db.add(producto)
            self.db.commit()
            self.db.refresh(producto)
            
        return producto