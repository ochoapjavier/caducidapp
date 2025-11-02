# backend/routers/products.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from database import get_db
from repositories.producto_maestro_repository import ProductoMaestroRepository
from schemas.item import ProductoMaestroSchema
from auth.firebase_auth import get_current_user_id

router = APIRouter()

# Schema para la actualización de un producto
class ProductUpdate(BaseModel):
    nombre: str
    marca: str | None = None

@router.get("/by-barcode/{barcode}", response_model=ProductoMaestroSchema)
def get_product_by_barcode(
    barcode: str, 
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id) # <-- AÑADIDO: Ruta protegida
):
    """Busca un producto maestro por su código de barras."""
    repo = ProductoMaestroRepository(db)
    # CORRECCIÓN: Usar el método que filtra por usuario y pasar el user_id.
    product = repo.get_by_barcode_and_user(barcode, user_id)
    if not product:
        # Es importante que si el producto no pertenece al usuario, se devuelva un 404.
        # El frontend está preparado para manejar este caso.
        raise HTTPException(status_code=404, detail="Producto no encontrado en el catálogo maestro.")
    return product

@router.put("/by-barcode/{barcode}", response_model=ProductoMaestroSchema)
def update_product_by_barcode(
    barcode: str, 
    product_update: ProductUpdate, 
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id) # <-- AÑADIDO: Ruta protegida
):
    """Actualiza el nombre y/o marca de un producto maestro existente."""
    repo = ProductoMaestroRepository(db)
    # CORRECCIÓN: Pasar el user_id al método de actualización.
    updated_product = repo.update_product_by_barcode(
        barcode=barcode,
        new_name=product_update.nombre,
        new_brand=product_update.marca,
        user_id=user_id
    )
    if not updated_product:
        raise HTTPException(status_code=404, detail="No se pudo actualizar. Producto no encontrado.")
    return updated_product
