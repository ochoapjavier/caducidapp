"""Router for household shopping list operations."""
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from database import get_db
import models
from schemas import shopping_list as schemas
from auth.firebase_auth import get_current_user_id
from dependencies import get_active_hogar_id

router = APIRouter(
    prefix="/shopping-list",
    tags=["Shopping List"]
)


@router.get("/hogar/{hogar_id}", response_model=List[schemas.ShoppingItemResponse])
async def get_shopping_list(
    hogar_id: int,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Obtener items de la lista de compra de un hogar.
    Verifica que el usuario autenticado pertenezca al hogar solicitado.
    """
    await get_active_hogar_id(x_hogar_id=hogar_id, user_id=user_id, db=db)

    items = (
        db.query(models.ShoppingListItem)
        .filter(models.ShoppingListItem.hogar_id == hogar_id)
        .order_by(
            models.ShoppingListItem.completado,
            models.ShoppingListItem.created_at.desc(),
        )
        .all()
    )
    return items


@router.post("/hogar/{hogar_id}", response_model=schemas.ShoppingItemResponse, status_code=status.HTTP_201_CREATED)
async def add_item_to_list(
    hogar_id: int,
    item: schemas.ShoppingItemCreate,
    user_id: Optional[str] = Query(None, description="Legacy query param for backward compatibility"),
    auth_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Añadir item a la lista de compra.
    Verifica membresía y utiliza siempre la identidad autenticada por token.
    Agrupa automáticamente si ya existe un ítem idéntico pendiente de compra.
    """
    await get_active_hogar_id(x_hogar_id=hogar_id, user_id=auth_user_id, db=db)

    existing_item = (
        db.query(models.ShoppingListItem)
        .filter(
            models.ShoppingListItem.hogar_id == hogar_id,
            models.ShoppingListItem.producto_nombre == item.producto_nombre,
            models.ShoppingListItem.completado == False,  # noqa: E712
        )
        .first()
    )

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
        added_by=auth_user_id,
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return new_item


@router.patch("/{item_id}", response_model=schemas.ShoppingItemResponse)
async def update_shopping_item(
    item_id: int,
    update_data: schemas.ShoppingItemUpdate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Actualizar estado o cantidad de un item.
    Verifica que el usuario pertenezca al hogar dueño del ítem.
    """
    item = db.query(models.ShoppingListItem).filter(models.ShoppingListItem.id == item_id).first()
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item de la lista de compra no encontrado",
        )

    await get_active_hogar_id(x_hogar_id=item.hogar_id, user_id=user_id, db=db)

    for key, value in update_data.model_dump(exclude_unset=True).items():
        setattr(item, key, value)

    db.commit()
    db.refresh(item)
    return item


@router.delete("/{item_id}")
async def delete_shopping_item(
    item_id: int,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Eliminar un item de la lista de compra.
    Verifica que el usuario pertenezca al hogar dueño del ítem.
    """
    item = db.query(models.ShoppingListItem).filter(models.ShoppingListItem.id == item_id).first()
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item de la lista de compra no encontrado",
        )

    await get_active_hogar_id(x_hogar_id=item.hogar_id, user_id=user_id, db=db)

    db.delete(item)
    db.commit()
    return {"message": "Item deleted"}


@router.post("/{item_id}/to-inventory")
async def move_to_inventory(
    item_id: int,
    ubicacion_id: int,
    fecha_caducidad: str,  # YYYY-MM-DD
    user_id: Optional[str] = Query(None, description="Legacy query param for backward compatibility"),
    auth_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Mover un item comprado al inventario activo.
    1. Valida membresía en el hogar del ítem.
    2. Valida que la ubicación de destino pertenezca al mismo hogar.
    3. Resuelve o crea el producto maestro.
    4. Crea la entrada en inventario_stock y retira el ítem de la lista.
    """
    item = db.query(models.ShoppingListItem).filter(models.ShoppingListItem.id == item_id).first()
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item de la lista de compra no encontrado",
        )

    await get_active_hogar_id(x_hogar_id=item.hogar_id, user_id=auth_user_id, db=db)

    # Validar que la ubicación pertenezca al hogar
    ubicacion = (
        db.query(models.Location)
        .filter(
            models.Location.id_ubicacion == ubicacion_id,
            models.Location.hogar_id == item.hogar_id,
        )
        .first()
    )
    if not ubicacion:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ubicación no encontrada o no pertenece a este hogar",
        )

    # Validar formato de fecha
    try:
        parsed_date = datetime.strptime(fecha_caducidad, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Formato de fecha inválido. Utiliza el formato YYYY-MM-DD",
        )

    # Obtener o crear producto maestro
    product_id = item.fk_producto
    if not product_id:
        existing_prod = (
            db.query(models.Product)
            .filter(
                models.Product.hogar_id == item.hogar_id,
                models.Product.nombre == item.producto_nombre,
            )
            .first()
        )

        if existing_prod:
            product_id = existing_prod.id_producto
        else:
            new_prod = models.Product(
                nombre=item.producto_nombre,
                hogar_id=item.hogar_id,
            )
            db.add(new_prod)
            db.commit()
            db.refresh(new_prod)
            product_id = new_prod.id_producto

    # Verificar si la ubicación es congelador
    estado_producto = "congelado" if ubicacion.es_congelador else "cerrado"
    fecha_congelacion = datetime.utcnow().date() if ubicacion.es_congelador else None

    new_stock = models.InventoryStock(
        hogar_id=item.hogar_id,
        fk_producto_maestro=product_id,
        fk_ubicacion=ubicacion_id,
        cantidad_actual=item.cantidad,
        fecha_caducidad=parsed_date,
        estado_producto=estado_producto,
        fecha_congelacion=fecha_congelacion,
    )
    db.add(new_stock)

    # Eliminar de la lista de compra al integrarse en inventario
    db.delete(item)
    db.commit()
    db.refresh(new_stock)

    return {"message": "Moved to inventory", "stock_id": new_stock.id_stock}
