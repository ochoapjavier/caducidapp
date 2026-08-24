# backend/routers/catalog.py
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from database import get_db
from dependencies import get_active_hogar_id, get_current_user_id
from repositories.product_repository import ProductRepository
from repositories.rating_repository import RatingRepository
from schemas import CatalogProductSchema, ProductRatingCreate, ProductRatingSchema

router = APIRouter(prefix="/catalog", tags=["Catalog & Ratings"])


from fastapi import APIRouter, Depends, HTTPException, Query, status, BackgroundTasks
from services.openfoodfacts_service import OpenFoodFactsService

@router.get("", response_model=list[CatalogProductSchema])
def get_catalog(
    background_tasks: BackgroundTasks,
    search: str | None = Query(None, description="Búsqueda por nombre, marca o código de barras"),
    only_favorites: bool = Query(False, description="Filtrar solo productos favoritos"),
    only_in_stock: bool = Query(False, description="Filtrar solo productos con unidades en stock"),
    only_realfood: bool = Query(False, description="Filtrar solo productos Comida Real (NOVA 1)"),
    only_high_iron: bool = Query(False, description="Filtrar solo productos altos/fuente de hierro (>= 2.1 mg/100g)"),
    only_high_protein: bool = Query(False, description="Filtrar solo productos altos en proteína (>= 10g/100g)"),
    only_low_sugar: bool = Query(False, description="Filtrar solo productos bajos en azúcar (<= 5g/100g)"),
    only_high_fiber: bool = Query(False, description="Filtrar solo productos altos en fibra (>= 3g/100g)"),
    min_rating: float | None = Query(None, ge=1.0, le=5.0, description="Puntuación promedio mínima"),
    sort_by: str = Query("name_asc", description="Ordenación: name_asc, rating_desc, rating_asc, stock_desc"),
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id),
    user_id: str = Depends(get_current_user_id),
):
    """Obtiene todos los productos del catálogo del hogar con stock total, valoración promedio y valoración personal."""
    product_repo = ProductRepository(db)
    items = product_repo.get_catalog_products(
        hogar_id=hogar_id,
        user_id=user_id,
        search=search,
        only_favorites=only_favorites,
        only_in_stock=only_in_stock,
        only_realfood=only_realfood,
        only_high_iron=only_high_iron,
        only_high_protein=only_high_protein,
        only_low_sugar=only_low_sugar,
        only_high_fiber=only_high_fiber,
        min_rating=min_rating,
        sort_by=sort_by,
    )

    background_tasks.add_task(OpenFoodFactsService.sync_missing_nutrition_for_hogar, None, hogar_id)
    return items


@router.get("/health-summary")
def get_catalog_health_summary(
    only_in_stock: bool = Query(True, description="Calcular métricas solo sobre productos en stock (default: True)"),
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id),
):
    """Obtiene las métricas consolidadas de salud y distribución de NOVA del inventario del hogar."""
    product_repo = ProductRepository(db)
    return product_repo.get_hogar_health_summary(hogar_id=hogar_id, only_in_stock=only_in_stock)


@router.get("/lookup-scan")
async def lookup_scan_product(
    barcode: str = Query(..., description="Código de barras EAN a escanear en supermercado"),
):
    """Endpoint efímero para escaneo de supermercado. Consulta OpenFoodFacts sin persistir en BD."""
    data = await OpenFoodFactsService.fetch_live_barcode_data(barcode)
    if not data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Producto con código {barcode} no encontrado en la base de datos nutricional.",
        )
    return data


@router.post("/{product_id}/rate", response_model=ProductRatingSchema)

def rate_product(
    product_id: int,
    rating_data: ProductRatingCreate,
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id),
    user_id: str = Depends(get_current_user_id),
):
    """Crea o actualiza la valoración de un producto para el usuario actual."""
    product_repo = ProductRepository(db)
    product = product_repo.get_by_id(product_id)
    
    if not product or product.hogar_id != hogar_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Producto no encontrado en el catálogo de este hogar."
        )

    rating_repo = RatingRepository(db)
    return rating_repo.upsert_rating(
        product_id=product_id,
        user_id=user_id,
        hogar_id=hogar_id,
        rating_data=rating_data
    )


@router.post("/{product_id}/favorite")
def toggle_product_favorite(
    product_id: int,
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id),
    user_id: str = Depends(get_current_user_id),
):
    """Alterna el estado de favorito de un producto para el usuario actual."""
    product_repo = ProductRepository(db)
    product = product_repo.get_by_id(product_id)
    
    if not product or product.hogar_id != hogar_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Producto no encontrado en el catálogo de este hogar."
        )

    rating_repo = RatingRepository(db)
    is_fav = rating_repo.toggle_favorite(
        product_id=product_id,
        user_id=user_id,
        hogar_id=hogar_id
    )
    return {"id_producto": product_id, "es_favorito": is_fav}


@router.delete("/{product_id}/rate")
def delete_product_rating(
    product_id: int,
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id),
    user_id: str = Depends(get_current_user_id),
):
    """Elimina la valoración del usuario para un producto."""
    product_repo = ProductRepository(db)
    product = product_repo.get_by_id(product_id)
    
    if not product or product.hogar_id != hogar_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Producto no encontrado en este hogar."
        )

    rating_repo = RatingRepository(db)
    deleted = rating_repo.delete_rating(product_id=product_id, user_id=user_id)
    return {"id_producto": product_id, "deleted": deleted}


@router.post("/{product_id}/fetch-nutrition")
async def fetch_product_nutrition_endpoint(
    product_id: int,
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id),
):
    """Consulta OpenFoodFacts por código de barras y guarda los datos de nutrición (NOVA, NutriScore, gramos/100g) en el producto."""
    product_repo = ProductRepository(db)
    product = product_repo.get_by_id(product_id)

    if not product or product.hogar_id != hogar_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Producto no encontrado en este hogar."
        )

    if not product.barcode:
        return {"status": "no_barcode", "message": "El producto no tiene código de barras."}

    from services.openfoodfacts_service import OpenFoodFactsService
    nutrition_data = await OpenFoodFactsService.fetch_product_nutrition(product.barcode)

    if not nutrition_data:
        return {"status": "not_found", "message": "No se encontraron datos en OpenFoodFacts."}

    updated = product_repo.update_product_nutrition(product_id, nutrition_data)
    return {"status": "success", "updated": updated, "nutrition": nutrition_data}


@router.post("/sync-bulk-nutrition")
async def sync_bulk_nutrition_endpoint(
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id),
):
    """Ejecuta un barrido masivo de información nutricional en OpenFoodFacts para todos los productos del hogar."""
    from services.openfoodfacts_service import OpenFoodFactsService
    updated_count = await OpenFoodFactsService.sync_all_missing_nutrition_for_hogar(db, hogar_id)
    return {"status": "success", "updated_count": updated_count}


from pydantic import BaseModel

class NutritionOverrideSchema(BaseModel):
    nova_group: int | None = None
    nutriscore_grade: str | None = None


@router.post("/{product_id}/override-nutrition")
def override_product_nutrition_endpoint(
    product_id: int,
    override_data: NutritionOverrideSchema,
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id),
):
    """Permite al usuario asignar o modificar manualmente el grupo NOVA y Nutri-Score de un producto."""
    product_repo = ProductRepository(db)
    product = product_repo.get_by_id(product_id)

    if not product or product.hogar_id != hogar_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Producto no encontrado en este hogar."
        )

    data_to_update = {}
    if override_data.nova_group is not None:
        data_to_update["nova_group"] = override_data.nova_group
    if override_data.nutriscore_grade is not None:
        clean_ns = override_data.nutriscore_grade.strip().lower()
        if clean_ns in ["a", "b", "c", "d", "e"]:
            data_to_update["nutriscore_grade"] = clean_ns

    updated = product_repo.update_product_nutrition(product_id, data_to_update)
    return {
        "status": "success",
        "updated": updated,
        "nova_group": product.nova_group,
        "nutriscore_grade": product.nutriscore_grade
    }


