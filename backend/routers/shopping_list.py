from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from database import get_db
import models
from schemas import shopping_list as schemas
from datetime import datetime

router = APIRouter(
    prefix="/shopping-list",
    tags=["Shopping List"]
)

@router.get("/hogar/{hogar_id}", response_model=List[schemas.ShoppingItemResponse])
def get_shopping_list(hogar_id: int, db: Session = Depends(get_db)):
    """Obtener items de la lista de compra de un hogar."""
    items = db.query(models.ShoppingListItem).filter(
        models.ShoppingListItem.hogar_id == hogar_id
    ).order_by(models.ShoppingListItem.completado, models.ShoppingListItem.created_at.desc()).all()
    return items

@router.post("/hogar/{hogar_id}", response_model=schemas.ShoppingItemResponse)
def add_item_to_list(
    hogar_id: int, 
    item: schemas.ShoppingItemCreate, 
    user_id: str, # En prod esto vendría del token
    db: Session = Depends(get_db)
):
    """Añadir item a la lista de compra."""
    # Verificar si ya existe un item no completado con el mismo nombre para agrupar
    existing_item = db.query(models.ShoppingListItem).filter(
        models.ShoppingListItem.hogar_id == hogar_id,
        models.ShoppingListItem.producto_nombre == item.producto_nombre,
        models.ShoppingListItem.completado == False
    ).first()

    if existing_item:
        existing_item.cantidad += item.cantidad
        db.commit()
        db.refresh(existing_item)
        return existing_item

    new_item = models.ShoppingListItem(
        hogar_id=hogar_id,
        producto_nombre=item.producto_nombre,
        fk_producto=item.fk_producto,
        cantidad=item.cantidad,
        added_by=user_id
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return new_item

@router.patch("/{item_id}", response_model=schemas.ShoppingItemResponse)
def update_shopping_item(item_id: int, update_data: schemas.ShoppingItemUpdate, db: Session = Depends(get_db)):
    """Actualizar estado o cantidad de un item."""
    item = db.query(models.ShoppingListItem).filter(models.ShoppingListItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    for key, value in update_data.dict(exclude_unset=True).items():
        setattr(item, key, value)
    
    db.commit()
    db.refresh(item)
    return item

@router.delete("/{item_id}")
def delete_shopping_item(item_id: int, db: Session = Depends(get_db)):
    """Eliminar un item de la lista."""
    item = db.query(models.ShoppingListItem).filter(models.ShoppingListItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    db.delete(item)
    db.commit()
    return {"message": "Item deleted"}

@router.post("/{item_id}/to-inventory")
def move_to_inventory(
    item_id: int, 
    ubicacion_id: int, 
    fecha_caducidad: str, # YYYY-MM-DD
    user_id: str,
    db: Session = Depends(get_db)
):
    """Mover un item comprado al inventario."""
    item = db.query(models.ShoppingListItem).filter(models.ShoppingListItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    # Crear entrada en inventario
    # Si no tiene fk_producto, necesitamos buscarlo o crearlo. 
    # Por simplificación, si no tiene fk_producto, fallamos o requerimos que se asocie primero.
    # En esta v1, asumiremos que si no tiene fk_producto, buscamos por nombre exacto o creamos uno básico.
    
    product_id = item.fk_producto
    if not product_id:
        # Buscar por nombre
        existing_prod = db.query(models.Product).filter(
            models.Product.hogar_id == item.hogar_id,
            models.Product.nombre == item.producto_nombre
        ).first()
        
        if existing_prod:
            product_id = existing_prod.id_producto
        else:
            # Crear producto maestro básico
            new_prod = models.Product(
                nombre=item.producto_nombre,
                hogar_id=item.hogar_id
            )
            db.add(new_prod)
            db.commit()
            db.refresh(new_prod)
            product_id = new_prod.id_producto

    new_stock = models.InventoryStock(
        hogar_id=item.hogar_id,
        fk_producto_maestro=product_id,
        fk_ubicacion=ubicacion_id,
        cantidad_actual=item.cantidad,
        fecha_caducidad=datetime.strptime(fecha_caducidad, "%Y-%m-%d").date(),
        estado_producto='cerrado'
    )
    
    db.add(new_stock)
    
    # Eliminar de la lista de compra (o marcar como completado/archivado)
    # Aquí decidimos eliminarlo para limpiar la lista
    db.delete(item)
    
    db.commit()
    return {"message": "Moved to inventory", "stock_id": new_stock.id_stock}
