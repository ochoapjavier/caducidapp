# backend/services/openfoodfacts_service.py
import json
import logging
import httpx
from datetime import datetime

logger = logging.getLogger(__name__)

class OpenFoodFactsService:
    BASE_URL = "https://world.openfoodfacts.org/api/v2/product"

    @staticmethod
    async def fetch_product_nutrition(barcode: str) -> dict | None:
        """Consulta la API de OpenFoodFacts para un código de barras y devuelve la estructura formateada."""
        if not barcode or not str(barcode).strip().isdigit():
            return None

        clean_barcode = str(barcode).strip()
        url = f"{OpenFoodFactsService.BASE_URL}/{clean_barcode}.json"

        try:
            async with httpx.AsyncClient(timeout=4.0) as client:
                res = await client.get(url, headers={"User-Agent": "Caducidapp - Python Backend"})
                if res.status_code != 200:
                    return None
                
                payload = res.json()
                product = payload.get("product", {})
                if not product:
                    return None

                # 1. NOVA Group (1: Comida Real, 2/3: Buen Procesado, 4: Ultraprocesado)
                nova_group = product.get("nova_group") or product.get("nova_groups")
                try:
                    nova_group = int(nova_group) if nova_group is not None else None
                except (ValueError, TypeError):
                    nova_group = None

                # 2. Nutri-Score (a - e)
                nutriscore_grade = product.get("nutriscore_grade") or product.get("nutrition_grades")
                if nutriscore_grade:
                    nutriscore_grade = str(nutriscore_grade).strip().lower()
                    if nutriscore_grade not in ["a", "b", "c", "d", "e"]:
                        nutriscore_grade = None

                # 3. Alérgenos limpios
                raw_allergens = product.get("allergens_tags", []) or []
                allergens = []
                for a in raw_allergens:
                    clean_a = str(a).replace("en:", "").replace("es:", "").strip()
                    if clean_a and clean_a not in allergens and clean_a != "none":
                        allergens.append(clean_a)

                # 4. Aditivos count
                additives_count = product.get("additives_n", 0)
                if not additives_count and product.get("additives_tags"):
                    additives_count = len(product.get("additives_tags"))

                # 5. Semáforo nutricional
                levels = product.get("nutrient_levels", {}) or {}
                semaforo = {
                    "fat": levels.get("fat", "unknown"),
                    "saturated_fat": levels.get("saturated-fat", "unknown"),
                    "sugars": levels.get("sugars", "unknown"),
                    "salt": levels.get("salt", "unknown"),
                }

                # 6. Nutrientes por 100g (incluyendo micronutrientes: Hierro, Fibra y Calcio)
                nutriments = product.get("nutriments", {}) or {}
                estimated = product.get("nutriments_estimated", {}) or {}

                def _first_not_none(*values):
                    for v in values:
                        if v is not None:
                            return v
                    return None

                def _extract_mg(key_name):
                    val = _first_not_none(
                        nutriments.get(f"{key_name}_100g"),
                        nutriments.get(key_name),
                        nutriments.get(f"{key_name}_value"),
                        nutriments.get(f"{key_name}_serving"),
                        estimated.get(f"{key_name}_100g"),
                        estimated.get(key_name)
                    )
                    if val is None:
                        return None
                    try:
                        f_val = float(val)
                        unit = str(nutriments.get(f"{key_name}_unit") or "").lower().strip()
                        if unit == "g" or (unit == "" and 0 < f_val < 0.1):
                            return round(f_val * 1000.0, 2)
                        return round(f_val, 2)
                    except (ValueError, TypeError):
                        return None

                def _extract_fiber():
                    val = _first_not_none(
                        nutriments.get("fiber_100g"),
                        nutriments.get("fiber"),
                        nutriments.get("fiber_value"),
                        nutriments.get("fiber_serving"),
                        estimated.get("fiber_100g"),
                        estimated.get("fiber")
                    )
                    if val is None:
                        return None
                    try:
                        f_val = float(val)
                        unit = str(nutriments.get("fiber_unit") or "").lower().strip()
                        if unit == "mg":
                            return round(f_val / 1000.0, 1)
                        return round(f_val, 1)
                    except (ValueError, TypeError):
                        return None

                iron_mg = _extract_mg("iron")
                fiber_g = _extract_fiber()
                calcium_mg = _extract_mg("calcium")




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


                return {
                    "nova_group": nova_group,
                    "nutriscore_grade": nutriscore_grade,
                    "alergenos": json.dumps(allergens, ensure_ascii=False),
                    "aditivos_count": additives_count or 0,
                    "semaforo_nutricional": json.dumps(semaforo, ensure_ascii=False),
                    "nutrientes_100g": json.dumps(nutrientes_100g, ensure_ascii=False),
                    "nutricion_sync_at": datetime.utcnow(),
                    "image_url": product.get("image_front_url") or product.get("image_url")
                }
        except Exception as e:
            logger.warning(f"Error fetching OpenFoodFacts for {barcode}: {e}")
            return None

    @staticmethod
    async def fetch_live_barcode_data(barcode: str) -> dict | None:
        """Consulta OpenFoodFacts para escaneo en supermercado en tiempo real sin guardar en BD."""
        data = await OpenFoodFactsService.fetch_product_nutrition(barcode)
        if not barcode or not str(barcode).strip().isdigit():
            return None

        clean_barcode = str(barcode).strip()
        url = f"{OpenFoodFactsService.BASE_URL}/{clean_barcode}.json"

        try:
            async with httpx.AsyncClient(timeout=4.0) as client:
                res = await client.get(url, headers={"User-Agent": "Caducidapp - Python Backend"})
                if res.status_code != 200:
                    return None
                
                payload = res.json()
                product = payload.get("product", {})
                if not product:
                    return None

                name = product.get("product_name_es") or product.get("product_name") or f"Producto {clean_barcode}"
                brand = product.get("brands") or product.get("brands_tags", [None])[0] if product.get("brands_tags") else None
                image_url = product.get("image_front_url") or product.get("image_url")

                # Reutilizamos el parser
                parsed = await OpenFoodFactsService.fetch_product_nutrition(clean_barcode)
                if not parsed:
                    return None

                return {
                    "barcode": clean_barcode,
                    "nombre": name,
                    "marca": brand,
                    "image_url": image_url,
                    "nova_group": parsed.get("nova_group"),
                    "nutriscore_grade": parsed.get("nutriscore_grade"),
                    "alergenos": parsed.get("alergenos"),
                    "aditivos_count": parsed.get("aditivos_count", 0),
                    "semaforo_nutricional": parsed.get("semaforo_nutricional"),
                    "nutrientes_100g": parsed.get("nutrientes_100g"),
                }
        except Exception as e:
            logger.warning(f"Error in fetch_live_barcode_data for {barcode}: {e}")
            return None


    @staticmethod
    async def sync_missing_nutrition_for_hogar(db_session_factory, hogar_id: int):
        """Tarea en segundo plano que descarga la información nutricional de productos con código de barras pendientes."""
        from database import SessionLocal
        from models import Product

        db = SessionLocal()
        try:
            from sqlalchemy import or_
            products = (
                db.query(Product)
                .filter(
                    Product.hogar_id == hogar_id,
                    Product.barcode.isnot(None),
                    or_(
                        Product.nutricion_sync_at.is_(None),
                        Product.nutrientes_100g.is_(None),
                        Product.nutrientes_100g.notlike("%iron_mg%")
                    )
                )
                .limit(25)
                .all()
            )


            for product in products:
                if product.barcode:
                    data = await OpenFoodFactsService.fetch_product_nutrition(product.barcode)
                    if data:
                        product.nova_group = data.get("nova_group")
                        product.nutriscore_grade = data.get("nutriscore_grade")
                        product.alergenos = data.get("alergenos")
                        product.aditivos_count = data.get("aditivos_count", 0)
                        product.semaforo_nutricional = data.get("semaforo_nutricional")
                        product.nutrientes_100g = data.get("nutrientes_100g")
                        product.nutricion_sync_at = datetime.utcnow()
                        if data.get("image_url") and not product.image_url:
                            product.image_url = data.get("image_url")
            db.commit()
        except Exception as e:
            logger.error(f"Error in background nutrition sync: {e}")
        finally:
            db.close()

