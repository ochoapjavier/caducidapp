# backend/repositories/producto_maestro_repository.py
from sqlalchemy.orm import Session
from sqlalchemy import func
from .models import ProductoMaestro

class ProductoMaestroRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_or_create_by_name(self, name: str, user_id: str) -> ProductoMaestro: # Ya recibía user_id, pero lo revisamos
        # Búsqueda insensible a mayúsculas y donde no hay código de barras
        producto = self.db.query(ProductoMaestro).filter(
            func.lower(ProductoMaestro.nombre) == func.lower(name),
            ProductoMaestro.barcode.is_(None),
            ProductoMaestro.user_id == user_id
        ).first()

        if not producto:
            producto = ProductoMaestro(nombre=name, user_id=user_id)
            self.db.add(producto)
            self.db.commit()
            self.db.refresh(producto)
        return producto

    def get_by_barcode_and_user(self, barcode: str, user_id: str) -> ProductoMaestro | None:
        """Busca un producto por su código de barras y que pertenezca al usuario."""
        # CORRECCIÓN: Hacemos la consulta más robusta usando `and_` para asegurar que ambas condiciones se aplican.
        from sqlalchemy import and_
        return self.db.query(ProductoMaestro).filter(
            and_(ProductoMaestro.barcode == barcode,
                 ProductoMaestro.user_id == user_id)
        ).first()

    def get_or_create_by_barcode(self, barcode: str, name: str, brand: str | None, user_id: str, image_url: str | None = None) -> ProductoMaestro:
        producto = self.get_by_barcode_and_user(barcode, user_id) # Busca el producto para este usuario

        if not producto:
            # Si no existe, lo crea con toda la información.
            producto = ProductoMaestro(
                barcode=barcode,
                nombre=name,
                marca=brand,
                user_id=user_id,
                image_url=image_url # Guardamos la URL de la imagen
            )
            self.db.add(producto)
            self.db.commit()
            self.db.refresh(producto)
        return producto # Devuelve el producto encontrado o el recién creado

    def update_product_by_barcode(self, barcode: str, user_id: str, new_name: str, new_brand: str | None) -> ProductoMaestro | None:
        """Busca un producto por barcode y usuario, y actualiza su nombre y marca."""
        # Ahora buscamos asegurando que el producto pertenece al usuario
        producto = self.get_by_barcode_and_user(barcode, user_id)

        if producto:
            producto.nombre = new_name
            producto.marca = new_brand
            self.db.commit()
            self.db.refresh(producto)
        # CORRECCIÓN: Devolver el objeto 'producto' actualizado, no el resultado de refresh.
        return producto