# backend/repositories/product_repository.py
from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from models import Product, InventoryStock, ProductRating

class ProductRepository:
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _normalize_optional_text(value: str | None) -> str | None:
        if value is None:
            return None

        normalized_value = value.strip()
        return normalized_value or None

    def get_by_id(self, product_id: int) -> Product | None:
        """Get a product by its ID."""
        return self.db.query(Product).filter(Product.id_producto == product_id).first()

    def get_or_create_by_name(
        self,
        name: str,
        hogar_id: int,
        brand: str | None = None,
        image_url: str | None = None,
    ) -> Product:
        """Get or create a product by name within a household (for products without barcode)."""
        normalized_brand = self._normalize_optional_text(brand)
        normalized_image_url = self._normalize_optional_text(image_url)

        # Case-insensitive search for household products without a barcode
        # Note: We don't filter by brand on search to avoid duplicates if brand is missing/different
        # We assume name is the primary identifier for manual products.
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
            product = Product(
                nombre=name,
                marca=normalized_brand,
                image_url=normalized_image_url,
                hogar_id=hogar_id,
            )
            self.db.add(product)
            self.db.commit()
            self.db.refresh(product)
        else:
            changed = False

            if normalized_brand and not product.marca:
                product.marca = normalized_brand
                changed = True

            if normalized_image_url and not product.image_url:
                product.image_url = normalized_image_url
                changed = True

            if changed:
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
        image_url: str | None = None,
    ) -> Product:
        """Get or create a product by barcode within a household."""
        normalized_brand = self._normalize_optional_text(brand)
        normalized_image_url = self._normalize_optional_text(image_url)
        product = self.get_by_barcode_and_hogar(barcode, hogar_id)
        if not product:
            product = Product(
                barcode=barcode,
                nombre=name,
                marca=normalized_brand,
                hogar_id=hogar_id,
                image_url=normalized_image_url,
            )
            self.db.add(product)
            self.db.commit()
            self.db.refresh(product)
        else:
            changed = False

            if normalized_brand and not product.marca:
                product.marca = normalized_brand
                changed = True

            if normalized_image_url and not product.image_url:
                product.image_url = normalized_image_url
                changed = True

            if changed:
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

    def search_by_name(self, query: str, hogar_id: int, limit: int = 10) -> list[Product]:
        """Search products by name (case-insensitive) within a household."""
        return (
            self.db.query(Product)
            .filter(
                Product.hogar_id == hogar_id,
                func.lower(Product.nombre).contains(func.lower(query))
            )
            .limit(limit)
            .all()
        )

    def get_catalog_products(
        self,
        hogar_id: int,
        user_id: str,
        search: str | None = None,
        only_favorites: bool = False,
        only_in_stock: bool = False,
        min_rating: float | None = None,
        sort_by: str = "name_asc"
    ) -> list[dict]:
        """Obtiene la lista de productos maestros del catálogo con métricas agregadas de stock y valoraciones."""
        
        # Subconsulta: Stock total por producto
        stock_subquery = (
            self.db.query(
                InventoryStock.fk_producto_maestro.label("id_producto"),
                func.coalesce(func.sum(InventoryStock.cantidad_actual), 0).label("stock_actual")
            )
            .filter(InventoryStock.hogar_id == hogar_id)
            .group_by(InventoryStock.fk_producto_maestro)
            .subquery()
        )

        # Subconsulta: Promedio y total de valoraciones del hogar por producto
        rating_stats_subquery = (
            self.db.query(
                ProductRating.fk_producto.label("id_producto"),
                func.avg(ProductRating.puntuacion).label("rating_promedio"),
                func.count(ProductRating.id_valoracion).label("total_valoraciones")
            )
            .filter(ProductRating.hogar_id == hogar_id)
            .group_by(ProductRating.fk_producto)
            .subquery()
        )

        # Subconsulta: Valoración del usuario actual
        user_rating_subquery = (
            self.db.query(
                ProductRating.fk_producto.label("id_producto"),
                ProductRating.puntuacion.label("mi_puntuacion"),
                ProductRating.es_favorito.label("es_favorito"),
                ProductRating.nota.label("mi_nota"),
                ProductRating.tags.label("mis_tags")
            )
            .filter(
                ProductRating.hogar_id == hogar_id,
                ProductRating.user_id == user_id
            )
            .subquery()
        )

        # Consulta Principal
        query = (
            self.db.query(
                Product.id_producto,
                Product.barcode,
                Product.nombre,
                Product.marca,
                Product.image_url,
                Product.dias_consumo_abierto,
                Product.hogar_id,
                func.coalesce(stock_subquery.c.stock_actual, 0).label("stock_actual"),
                rating_stats_subquery.c.rating_promedio,
                func.coalesce(rating_stats_subquery.c.total_valoraciones, 0).label("total_valoraciones"),
                user_rating_subquery.c.mi_puntuacion,
                func.coalesce(user_rating_subquery.c.es_favorito, False).label("es_favorito"),
                user_rating_subquery.c.mi_nota,
                user_rating_subquery.c.mis_tags
            )
            .outerjoin(stock_subquery, Product.id_producto == stock_subquery.c.id_producto)
            .outerjoin(rating_stats_subquery, Product.id_producto == rating_stats_subquery.c.id_producto)
            .outerjoin(user_rating_subquery, Product.id_producto == user_rating_subquery.c.id_producto)
            .filter(Product.hogar_id == hogar_id)
        )

        if search and search.strip():
            clean_search = search.strip().lower()
            # Quitamos símbolos de puntuación/hashtags para búsqueda flexible
            raw_keyword = clean_search.lstrip("#¡!").rstrip("!").strip()

            search_pattern = f"%{clean_search}%"
            keyword_pattern = f"%{raw_keyword}%" if raw_keyword else search_pattern

            query = query.filter(
                func.lower(Product.nombre).like(search_pattern) |
                func.lower(Product.nombre).like(keyword_pattern) |
                func.lower(func.coalesce(Product.marca, "")).like(search_pattern) |
                func.lower(func.coalesce(Product.marca, "")).like(keyword_pattern) |
                Product.barcode.like(search_pattern) |
                func.lower(func.coalesce(user_rating_subquery.c.mis_tags, "")).like(search_pattern) |
                func.lower(func.coalesce(user_rating_subquery.c.mis_tags, "")).like(keyword_pattern) |
                func.lower(func.coalesce(user_rating_subquery.c.mi_nota, "")).like(search_pattern) |
                func.lower(func.coalesce(user_rating_subquery.c.mi_nota, "")).like(keyword_pattern)
            )



        if only_favorites:
            query = query.filter(user_rating_subquery.c.es_favorito.is_(True))

        if only_in_stock:
            query = query.filter(stock_subquery.c.stock_actual > 0)

        if min_rating is not None and min_rating > 0:
            query = query.filter(rating_stats_subquery.c.rating_promedio >= min_rating)

        if sort_by == "rating_desc":
            query = query.order_by(rating_stats_subquery.c.rating_promedio.desc().nullslast(), Product.nombre.asc())
        elif sort_by == "rating_asc":
            query = query.order_by(rating_stats_subquery.c.rating_promedio.asc().nullslast(), Product.nombre.asc())
        elif sort_by == "stock_desc":
            query = query.order_by(stock_subquery.c.stock_actual.desc().nullslast(), Product.nombre.asc())
        else:
            query = query.order_by(Product.nombre.asc())

        results = query.all()

        catalog_items = []
        for row in results:
            rating_prom = float(row.rating_promedio) if row.rating_promedio is not None else None
            if rating_prom is not None:
                rating_prom = round(rating_prom, 1)

            catalog_items.append({
                "id_producto": row.id_producto,
                "barcode": row.barcode,
                "nombre": row.nombre,
                "marca": row.marca,
                "image_url": row.image_url,
                "dias_consumo_abierto": row.dias_consumo_abierto,
                "hogar_id": row.hogar_id,
                "stock_actual": int(row.stock_actual or 0),
                "rating_promedio": rating_prom,
                "total_valoraciones": int(row.total_valoraciones or 0),
                "mi_puntuacion": float(row.mi_puntuacion) if row.mi_puntuacion is not None else None,
                "es_favorito": bool(row.es_favorito),
                "mi_nota": row.mi_nota,
                "mis_tags": row.mis_tags,
            })

        return catalog_items

