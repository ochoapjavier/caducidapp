# backend/repositories/producto_maestro_repository.py
from sqlalchemy.orm import Session
from sqlalchemy import func
from .models import ProductoMaestro

class ProductoMaestroRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_or_create_by_name(self, name: str) -> ProductoMaestro:
        # Búsqueda insensible a mayúsculas y donde no hay código de barras
        producto = self.db.query(ProductoMaestro).filter(
            func.lower(ProductoMaestro.nombre) == func.lower(name),
            ProductoMaestro.barcode.is_(None)
        ).first()

        if not producto:
            producto = ProductoMaestro(nombre=name)
            self.db.add(producto)
            self.db.commit()
            self.db.refresh(producto)
        return producto

    def get_by_barcode(self, barcode: str) -> ProductoMaestro | None:
        """Busca un producto únicamente por su código de barras."""
        return self.db.query(ProductoMaestro).filter(ProductoMaestro.barcode == barcode).first()

    def get_or_create_by_barcode(self, barcode: str, name: str, brand: str | None) -> ProductoMaestro:
        # Busca primero por el código de barras, que es un identificador único.
        producto = self.db.query(ProductoMaestro).filter(ProductoMaestro.barcode == barcode).first()

        if not producto:
            # Si no existe, lo crea con toda la información.
            producto = ProductoMaestro(barcode=barcode, nombre=name, marca=brand)
            self.db.add(producto)
            self.db.commit()
            self.db.refresh(producto)
        
        return producto

    def update_product_by_barcode(self, barcode: str, new_name: str, new_brand: str | None) -> ProductoMaestro | None:
        """Busca un producto por barcode y actualiza su nombre y marca."""
        producto = self.get_by_barcode(barcode)

        if producto:
            producto.nombre = new_name
            producto.marca = new_brand
            self.db.commit()
            self.db.refresh(producto)
        
        return producto