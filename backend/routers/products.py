# backend/routers/products.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from repositories.product_repository import ProductRepository
from schemas import ProductSchema, ProductUpdate
from dependencies import get_active_hogar_id

router = APIRouter()

@router.get("/by-barcode/{barcode}", response_model=ProductSchema)
def get_product_by_barcode(
    barcode: str, 
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id)
):
    """Find a master product by barcode in the household."""
    repo = ProductRepository(db)
    product = repo.get_by_barcode_and_hogar(barcode, hogar_id)
    if not product:
        raise HTTPException(status_code=404, detail="Producto no encontrado en el catálogo del hogar.")
    return product

@router.put("/by-barcode/{barcode}", response_model=ProductSchema)
def update_product_by_barcode(
    barcode: str, 
    product_update: ProductUpdate, 
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id)
):
    """Update name and/or brand of an existing master product in the household."""
    repo = ProductRepository(db)
    updated_product = repo.update_product_by_barcode(
        barcode=barcode,
        new_name=product_update.nombre,
        new_brand=product_update.marca,
        hogar_id=hogar_id
    )
    if not updated_product:
        raise HTTPException(status_code=404, detail="No se pudo actualizar. Producto no encontrado.")
    return updated_product
    return updated_product

@router.get("/search", response_model=list[ProductSchema])
def search_products(
    query: str,
    db: Session = Depends(get_db),
    hogar_id: int = Depends(get_active_hogar_id)
):
    """Search products by name in the household."""
    repo = ProductRepository(db)
    # Asumimos que el repositorio tiene un método search_by_name o similar.
    # Si no, lo implementaremos en el repositorio también.
    # Por ahora, usaremos una consulta directa si el repo no lo soporta, 
    # pero lo ideal es usar el repo.
    # Vamos a verificar el repo primero.
    return repo.search_by_name(query, hogar_id)
