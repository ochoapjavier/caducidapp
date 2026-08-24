# backend/repositories/product_repository.py
from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from datetime import datetime
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

        # Sincronización inmediata si no tiene nutrición guardada o falta la info de hierro
        if product.barcode and (product.nutricion_sync_at is None or product.nutrientes_100g is None or "iron_mg" not in (product.nutrientes_100g or "")):
            try:
                import httpx, json
                url = f"https://world.openfoodfacts.org/api/v2/product/{product.barcode}.json"
                with httpx.Client(timeout=3.0) as client:
                    res = client.get(url, headers={"User-Agent": "Caducidapp"})
                    if res.status_code == 200:
                        payload = res.json().get("product", {})
                        if payload:
                            nova = payload.get("nova_group") or payload.get("nova_groups")
                            try:
                                product.nova_group = int(nova) if nova is not None else None
                            except Exception:
                                pass
                            
                            ns = payload.get("nutriscore_grade") or payload.get("nutrition_grades")
                            if ns:
                                product.nutriscore_grade = str(ns).strip().lower()

                            raw_a = payload.get("allergens_tags", []) or []
                            allergens = [str(a).replace("en:", "").replace("es:", "").strip() for a in raw_a if str(a) != "none"]
                            product.alergenos = json.dumps(allergens, ensure_ascii=False)

                            product.aditivos_count = payload.get("additives_n", 0) or len(payload.get("additives_tags", []))
                            product.semaforo_nutricional = json.dumps(payload.get("nutrient_levels", {}), ensure_ascii=False)

                            nutriments = payload.get("nutriments", {}) or {}
                            estimated = payload.get("nutriments_estimated", {}) or {}

                            def _first_nn(*vals):
                                for v in vals:
                                    if v is not None: return v
                                return None

                            def _parse_mg(key):
                                val = _first_nn(nutriments.get(f"{key}_100g"), nutriments.get(key), nutriments.get(f"{key}_value"), estimated.get(f"{key}_100g"))
                                if val is None: return None
                                try:
                                    f_val = float(val)
                                    unit = str(nutriments.get(f"{key}_unit") or "").lower().strip()
                                    if unit == "g" or (unit == "" and 0 < f_val < 0.1):
                                        return round(f_val * 1000.0, 2)
                                    return round(f_val, 2)
                                except (ValueError, TypeError): return None

                            def _parse_fiber():
                                val = _first_nn(nutriments.get("fiber_100g"), nutriments.get("fiber"), nutriments.get("fiber_value"), estimated.get("fiber_100g"))
                                if val is None: return None
                                try:
                                    f_val = float(val)
                                    unit = str(nutriments.get("fiber_unit") or "").lower().strip()
                                    if unit == "mg": return round(f_val / 1000.0, 1)
                                    return round(f_val, 1)
                                except (ValueError, TypeError): return None

                            iron_mg = _parse_mg("iron")
                            fiber_g = _parse_fiber()
                            calcium_mg = _parse_mg("calcium")



                            nutrientes_100g = {
                                "energy_kcal": nutriments.get("energy-kcal_100g") or nutriments.get("energy-kcal"),
                                "carbohydrates": nutriments.get("carbohydrates_100g") or nutriments.get("carbohydrates"),
                                "sugars": nutriments.get("sugars_100g") or nutriments.get("sugars"),
                                "fat": nutriments.get("fat_100g") or nutriments.get("fat"),
                                "saturated_fat": nutriments.get("saturated-fat_100g") or nutriments.get("saturated-fat"),
                                "proteins": nutriments.get("proteins_100g") or nutriments.get("proteins"),
                                "salt": nutriments.get("salt_100g") or nutriments.get("salt"),
                                "iron_mg": iron_mg,
                                "fiber": fiber_g,
                                "calcium_mg": calcium_mg,
                            }
                            product.nutrientes_100g = json.dumps(nutrientes_100g, ensure_ascii=False)

                            if not product.image_url and payload.get("image_front_url"):
                                product.image_url = payload.get("image_front_url")

                            product.nutricion_sync_at = datetime.utcnow()
                            self.db.commit()
            except Exception as e:
                pass


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
        only_realfood: bool = False,
        only_high_iron: bool = False,
        only_high_protein: bool = False,
        only_low_sugar: bool = False,
        only_high_fiber: bool = False,
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
                Product.nova_group,
                Product.nutriscore_grade,
                Product.alergenos,
                Product.aditivos_count,
                Product.semaforo_nutricional,
                Product.nutrientes_100g,
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

        if only_realfood:
            # Solo productos Comida Real (NOVA 1)
            query = query.filter(Product.nova_group == 1)



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
                "nova_group": row.nova_group,
                "nutriscore_grade": row.nutriscore_grade,
                "alergenos": row.alergenos,
                "aditivos_count": row.aditivos_count,
                "semaforo_nutricional": row.semaforo_nutricional,
                "nutrientes_100g": row.nutrientes_100g,
            })

        if only_high_iron or only_high_protein or only_low_sugar or only_high_fiber:
            filtered = []
            import json
            for item in catalog_items:
                raw_n = item.get("nutrientes_100g")
                if raw_n:
                    try:
                        n_map = json.loads(raw_n) if isinstance(raw_n, str) else raw_n
                        match = True
                        if only_high_iron:
                            iron_mg = n_map.get("iron_mg")
                            if iron_mg is None or float(iron_mg) < 2.1:
                                match = False
                        if only_high_protein:
                            proteins = n_map.get("proteins")
                            if proteins is None or float(proteins) < 10.0:
                                match = False
                        if only_low_sugar:
                            sugars = n_map.get("sugars")
                            if sugars is None or float(sugars) > 5.0:
                                match = False
                        if only_high_fiber:
                            fiber = n_map.get("fiber")
                            if fiber is None or float(fiber) < 3.0:
                                match = False

                        if match:
                            filtered.append(item)
                    except Exception:
                        pass
            catalog_items = filtered

        return catalog_items

    def get_hogar_health_summary(self, hogar_id: int, only_in_stock: bool = True) -> dict:
        """Calcula las métricas globales de salud y distribución NOVA del stock del hogar."""
        if only_in_stock:
            stock_subquery = (
                self.db.query(
                    InventoryStock.fk_producto_maestro.label("id_producto"),
                    func.coalesce(func.sum(InventoryStock.cantidad_actual), 0).label("stock_actual")
                )
                .filter(InventoryStock.hogar_id == hogar_id)
                .group_by(InventoryStock.fk_producto_maestro)
                .subquery()
            )
            products = (
                self.db.query(Product)
                .join(stock_subquery, Product.id_producto == stock_subquery.c.id_producto)
                .filter(Product.hogar_id == hogar_id, stock_subquery.c.stock_actual > 0)
                .all()
            )
        else:
            products = self.db.query(Product).filter(Product.hogar_id == hogar_id).all()

        total_products = len(products)
        if total_products == 0:
            return {
                "total_products": 0,
                "realfood_count": 0,
                "processed_count": 0,
                "ultraprocessed_count": 0,
                "realfood_pct": 0.0,
                "processed_pct": 0.0,
                "ultraprocessed_pct": 0.0,
                "health_score": 10.0,
                "high_iron_count": 0,
                "high_protein_count": 0,
                "high_fiber_count": 0,
            }

        realfood_count = 0
        processed_count = 0
        ultraprocessed_count = 0
        high_iron_count = 0
        high_protein_count = 0
        high_fiber_count = 0

        import json
        for p in products:
            if p.nova_group == 1:
                realfood_count += 1
            elif p.nova_group in [2, 3]:
                processed_count += 1
            elif p.nova_group == 4:
                ultraprocessed_count += 1

            if p.nutrientes_100g:
                try:
                    n_map = json.loads(p.nutrientes_100g) if isinstance(p.nutrientes_100g, str) else p.nutrientes_100g
                    if n_map.get("iron_mg") is not None and float(n_map["iron_mg"]) >= 2.1:
                        high_iron_count += 1
                    if n_map.get("proteins") is not None and float(n_map["proteins"]) >= 10.0:
                        high_protein_count += 1
                    if n_map.get("fiber") is not None and float(n_map["fiber"]) >= 3.0:
                        high_fiber_count += 1
                except Exception:
                    pass

        total_classified = realfood_count + processed_count + ultraprocessed_count
        base = total_classified if total_classified > 0 else 1
        rf_pct = round((realfood_count / base) * 100, 1)
        pr_pct = round((processed_count / base) * 100, 1)
        up_pct = round((ultraprocessed_count / base) * 100, 1)

        # Mapeo oficial Nutri-Score (Escala FSAn-NPS / OMS)
        ns_map = {'a': 10.0, 'b': 8.0, 'c': 6.0, 'd': 4.0, 'e': 2.0}
        # Mapeo oficial clasificación NOVA (Grado de procesamiento industrial OMS/FAO)
        nova_map = {1: 10.0, 2: 7.5, 3: 5.0, 4: 1.5}

        scores = []
        for p in products:
            p_scores = []
            if p.nutriscore_grade and p.nutriscore_grade.lower() in ns_map:
                p_scores.append(ns_map[p.nutriscore_grade.lower()])
            if p.nova_group and p.nova_group in nova_map:
                p_scores.append(nova_map[p.nova_group])

            if p_scores:
                scores.append(sum(p_scores) / len(p_scores))

        if scores:
            health_score = round(sum(scores) / len(scores), 1)
        else:
            health_score = 7.0

        return {
            "total_products": total_products,
            "realfood_count": realfood_count,
            "processed_count": processed_count,
            "ultraprocessed_count": ultraprocessed_count,
            "realfood_pct": rf_pct,
            "processed_pct": pr_pct,
            "ultraprocessed_pct": up_pct,
            "health_score": health_score,
            "high_iron_count": high_iron_count,
            "high_protein_count": high_protein_count,
            "high_fiber_count": high_fiber_count,
        }


    def update_product_nutrition(self, product_id: int, nutrition_data: dict) -> bool:
        """Actualiza los datos nutricionales de un producto maestro en la base de datos."""
        product = self.db.query(Product).filter(Product.id_producto == product_id).first()
        if not product:
            return False

        if "nova_group" in nutrition_data and nutrition_data["nova_group"] is not None:
            product.nova_group = nutrition_data["nova_group"]
        if "nutriscore_grade" in nutrition_data and nutrition_data["nutriscore_grade"] is not None:
            product.nutriscore_grade = nutrition_data["nutriscore_grade"]
        if "alergenos" in nutrition_data:
            product.alergenos = nutrition_data["alergenos"]
        if "aditivos_count" in nutrition_data:
            product.aditivos_count = nutrition_data["aditivos_count"]
        if "semaforo_nutricional" in nutrition_data:
            product.semaforo_nutricional = nutrition_data["semaforo_nutricional"]
        if "nutrientes_100g" in nutrition_data:
            product.nutrientes_100g = nutrition_data["nutrientes_100g"]
        if "image_url" in nutrition_data and nutrition_data["image_url"] and not product.image_url:
            product.image_url = nutrition_data["image_url"]

        product.nutricion_sync_at = datetime.utcnow()
        self.db.commit()
        return True
