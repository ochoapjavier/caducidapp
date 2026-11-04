"""Unit and integration tests for ProductActionsService (open, freeze, unfreeze, relocate)."""
from datetime import date, timedelta
import pytest
from fastapi import HTTPException

import models
from services.product_actions_service import ProductActionsService


def test_open_product_success(db_session, test_hogar, test_locations, test_product):
    """Test opening a sealed product unit recalculates expiration and tracks state."""
    service = ProductActionsService(db_session)
    original_expiry = date.today() + timedelta(days=30)

    # 1. Create 3 sealed units in fridge
    stock = models.InventoryStock(
        hogar_id=test_hogar.id_hogar,
        fk_producto_maestro=test_product.id_producto,
        fk_ubicacion=test_locations["nevera"].id_ubicacion,
        cantidad_actual=3,
        fecha_caducidad=original_expiry,
        estado_producto="cerrado",
    )
    db_session.add(stock)
    db_session.commit()
    db_session.refresh(stock)

    # 2. Open 1 unit with 4 days shelf life
    result = service.open_product(
        stock_id=stock.id_stock,
        hogar_id=test_hogar.id_hogar,
        cantidad=1,
        nueva_ubicacion_id=None,
        mantener_fecha_caducidad=False,
        dias_vida_util=4,
    )

    assert result["cantidad_procesada"] == 1
    assert result["item_nuevo_id"] is not None

    # 3. Check original item has 2 units remaining
    db_session.refresh(stock)
    assert stock.cantidad_actual == 2
    assert stock.estado_producto == "cerrado"

    # 4. Check new opened item
    new_item = db_session.query(models.InventoryStock).filter_by(id_stock=result["item_nuevo_id"]).first()
    assert new_item is not None
    assert new_item.cantidad_actual == 1
    assert new_item.estado_producto == "abierto"
    assert new_item.fecha_apertura == date.today()
    assert new_item.fecha_caducidad == date.today() + timedelta(days=4)


def test_open_product_exceeds_quantity_raises_error(db_session, test_hogar, test_locations, test_product):
    """Attempting to open more units than available raises HTTP 400."""
    service = ProductActionsService(db_session)
    stock = models.InventoryStock(
        hogar_id=test_hogar.id_hogar,
        fk_producto_maestro=test_product.id_producto,
        fk_ubicacion=test_locations["nevera"].id_ubicacion,
        cantidad_actual=1,
        fecha_caducidad=date.today() + timedelta(days=10),
        estado_producto="cerrado",
    )
    db_session.add(stock)
    db_session.commit()

    with pytest.raises(HTTPException) as exc_info:
        service.open_product(
            stock_id=stock.id_stock,
            hogar_id=test_hogar.id_hogar,
            cantidad=5,
            nueva_ubicacion_id=None,
            mantener_fecha_caducidad=False,
            dias_vida_util=3,
        )
    assert exc_info.value.status_code == 400


def test_freeze_product_success(db_session, test_hogar, test_locations, test_product):
    """Test freezing a product moves it to freezer location and marks estado as 'congelado'."""
    service = ProductActionsService(db_session)
    original_expiry = date.today() + timedelta(days=5)

    stock = models.InventoryStock(
        hogar_id=test_hogar.id_hogar,
        fk_producto_maestro=test_product.id_producto,
        fk_ubicacion=test_locations["nevera"].id_ubicacion,
        cantidad_actual=2,
        fecha_caducidad=original_expiry,
        estado_producto="cerrado",
    )
    db_session.add(stock)
    db_session.commit()

    # Freeze 1 unit into freezer
    result = service.freeze_product(
        stock_id=stock.id_stock,
        hogar_id=test_hogar.id_hogar,
        cantidad=1,
        ubicacion_congelador_id=test_locations["congelador"].id_ubicacion,
    )

    assert result["cantidad_procesada"] == 1
    frozen_item = db_session.query(models.InventoryStock).filter_by(id_stock=result["item_nuevo_id"]).first()
    assert frozen_item.estado_producto == "congelado"
    assert frozen_item.fk_ubicacion == test_locations["congelador"].id_ubicacion
    assert frozen_item.fecha_congelacion == date.today()


def test_unfreeze_product_to_freezer_rejected(db_session, test_hogar, test_locations, test_product):
    """Unfreezing directly to another freezer location must be rejected (HTTP 400)."""
    service = ProductActionsService(db_session)

    frozen_stock = models.InventoryStock(
        hogar_id=test_hogar.id_hogar,
        fk_producto_maestro=test_product.id_producto,
        fk_ubicacion=test_locations["congelador"].id_ubicacion,
        cantidad_actual=1,
        fecha_caducidad=date.today() + timedelta(days=10),
        estado_producto="congelado",
        fecha_congelacion=date.today() - timedelta(days=14),
    )
    db_session.add(frozen_stock)
    db_session.commit()

    with pytest.raises(HTTPException) as exc_info:
        service.unfreeze_product(
            stock_id=frozen_stock.id_stock,
            hogar_id=test_hogar.id_hogar,
            cantidad=1,
            nueva_ubicacion_id=test_locations["congelador"].id_ubicacion,
            dias_vida_util=2,
        )
    assert exc_info.value.status_code == 400
    assert "congelador" in exc_info.value.detail.lower()


def test_relocate_product_merges_with_matching_existing_item(db_session, test_hogar, test_locations, test_product):
    """Relocating merges quantity when an identical item already exists in target location."""
    service = ProductActionsService(db_session)
    expiry = date.today() + timedelta(days=20)

    # Item in Pantry
    pantry_item = models.InventoryStock(
        hogar_id=test_hogar.id_hogar,
        fk_producto_maestro=test_product.id_producto,
        fk_ubicacion=test_locations["despensa"].id_ubicacion,
        cantidad_actual=2,
        fecha_caducidad=expiry,
        estado_producto="cerrado",
    )
    # Target item in Fridge with same expiry and state
    fridge_item = models.InventoryStock(
        hogar_id=test_hogar.id_hogar,
        fk_producto_maestro=test_product.id_producto,
        fk_ubicacion=test_locations["nevera"].id_ubicacion,
        cantidad_actual=1,
        fecha_caducidad=expiry,
        estado_producto="cerrado",
    )
    db_session.add_all([pantry_item, fridge_item])
    db_session.commit()

    result = service.relocate_product(
        stock_id=pantry_item.id_stock,
        hogar_id=test_hogar.id_hogar,
        cantidad=2,
        nueva_ubicacion_id=test_locations["nevera"].id_ubicacion,
    )

    # Pantry item was completely moved, so it should be deleted
    assert result["item_original_id"] is None
    assert result["item_nuevo_id"] == fridge_item.id_stock

    db_session.refresh(fridge_item)
    assert fridge_item.cantidad_actual == 3

