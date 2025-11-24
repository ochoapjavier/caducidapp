# backend/repositories/product_repository.py
from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from models import Product

class ProductRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_or_create_by_name(self, name: str, hogar_id: int, user_id: str) -> Product:
        """Get or create a product by name within a household (for products without barcode)."""
        # Case-insensitive search for household products without a barcode
        product = (
            self.db.query(Product)
            .filter(
                func.lower(Product.nombre) == func.lower(name),
                Product.barcode.is_(None),
                Product.hogar_id == hogar_id,
            )
            .first()
        )

        if not product:
            product = Product(nombre=name, hogar_id=hogar_id, user_id=user_id)
            self.db.add(product)
            self.db.commit()
            self.db.refresh(product)
        return product

    def get_by_barcode_and_hogar(self, barcode: str, hogar_id: int) -> Product | None:
        """Find a product by its barcode within a household."""
        return (
            self.db.query(Product)
            .filter(and_(Product.barcode == barcode, Product.hogar_id == hogar_id))
            .first()
        )

    def get_or_create_by_barcode(
        self,
        barcode: str,
        name: str,
        brand: str | None,
        hogar_id: int,
        user_id: str,
        image_url: str | None = None,
    ) -> Product:
        """Get or create a product by barcode within a household."""
        product = self.get_by_barcode_and_hogar(barcode, hogar_id)
        if not product:
            product = Product(
                barcode=barcode,
                nombre=name,
                marca=brand,
                hogar_id=hogar_id,
                user_id=user_id,
                image_url=image_url,
            )
            self.db.add(product)
            self.db.commit()
            self.db.refresh(product)
        return product

    def update_product_by_barcode(
        self, barcode: str, hogar_id: int, new_name: str, new_brand: str | None
    ) -> Product | None:
        """Update name/brand for a product identified by (barcode, hogar)."""
        product = self.get_by_barcode_and_hogar(barcode, hogar_id)
        if product:
            product.nombre = new_name
            product.marca = new_brand
            self.db.commit()
            self.db.refresh(product)
        return product
