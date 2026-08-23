# backend/routers/catalog.py
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from database import get_db
from dependencies import get_active_hogar_id, get_current_user_id
from repositories.product_repository import ProductRepository
from repositories.rating_repository import RatingRepository
from schemas import CatalogProductSchema, ProductRatingCreate, ProductRatingSchema

router = APIRouter(prefix="/catalog", tags=["Catalog & Ratings"])


@router.get("", response_model=list[CatalogProductSchema])
def get_catalog(
    search: str | None = Query(None, description="Búsqueda por nombre, marca o código de barras"),
    only_favorites: bool = Query(False, description="Filtrar solo productos favoritos"),
    only_in_stock: bool = Query(False, description="Filtrar solo productos con unidades en stock"),
    min_rating: float | None = Query(None, ge=1.0, le=5.0, description="Puntuación promedio mínima"),
    sort_by: str = Query("name_asc", description="Ordenación: name_asc, rating_desc, rating_asc, stock_desc"),
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id),
    user_id: str = Depends(get_current_user_id),
):
    """Obtiene todos los productos del catálogo del hogar con stock total, valoración promedio y valoración personal."""
    product_repo = ProductRepository(db)
    return product_repo.get_catalog_products(
        hogar_id=hogar_id,
        user_id=user_id,
        search=search,
        only_favorites=only_favorites,
        only_in_stock=only_in_stock,
        min_rating=min_rating,
        sort_by=sort_by,
    )


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
