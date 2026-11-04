"""Tests for StockService (stock creation, consumption, and household transfer)."""
from datetime import date, timedelta
import pytest
from fastapi import HTTPException

import models
from services.stock_service import StockService
from schemas.item import StockItemCreate


def test_process_manual_stock_creation_and_grouping(db_session, test_hogar, test_locations, test_product, test_user_id):
    """Adding stock with identical expiry and location groups into a single row."""
    service = StockService(db_session)
    expiry = date.today() + timedelta(days=10)

    item1 = StockItemCreate(
        product_name=test_product.nombre,
        brand=test_product.marca,
        barcode=test_product.barcode,
        cantidad=2,
        fecha_caducidad=expiry,
        ubicacion_id=test_locations["nevera"].id_ubicacion,
    )
    res1 = service.process_manual_stock(item1, test_hogar.id_hogar, test_user_id)
    assert res1.cantidad_actual == 2

    # Add 3 more units of the exact same product, expiry, and location
    item2 = StockItemCreate(
        product_name=test_product.nombre,
        brand=test_product.marca,
        barcode=test_product.barcode,
        cantidad=3,
        fecha_caducidad=expiry,
        ubicacion_id=test_locations["nevera"].id_ubicacion,
    )
    res2 = service.process_manual_stock(item2, test_hogar.id_hogar, test_user_id)

    # Should have updated the same stock entry to 5 units
    assert res2.id_stock == res1.id_stock
    assert res2.cantidad_actual == 5


def test_consume_stock_item(db_session, test_hogar, test_locations, test_product):
    """Consuming 1 unit decrements count; consuming the last unit deletes the item."""
    service = StockService(db_session)
    expiry = date.today() + timedelta(days=7)

    stock = models.InventoryStock(
        hogar_id=test_hogar.id_hogar,
        fk_producto_maestro=test_product.id_producto,
        fk_ubicacion=test_locations["nevera"].id_ubicacion,
        cantidad_actual=2,
        fecha_caducidad=expiry,
        estado_producto="cerrado",
    )
    db_session.add(stock)
    db_session.commit()
    db_session.refresh(stock)

    # 1. Consume 1 unit -> 1 unit remains
    res1 = service.consume_stock_item(stock.id_stock, test_hogar.id_hogar)
    assert res1["status"] == "updated"
    assert res1["message"] == "Cantidad reducida en 1."
    assert res1["new_quantity"] == 1

    # 2. Consume last unit -> deleted
    res2 = service.consume_stock_item(stock.id_stock, test_hogar.id_hogar)
    assert res2["status"] == "deleted"
    assert "eliminado" in res2["message"]

    deleted_check = db_session.query(models.InventoryStock).filter_by(id_stock=stock.id_stock).first()
    assert deleted_check is None


def test_transfer_stock_between_households(db_session, test_hogar, test_locations, test_product, test_user_id):
    """Transferring stock creates or groups product in target household and decrements source."""
    service = StockService(db_session)
    expiry = date.today() + timedelta(days=12)

    # Target household
    target_hogar = models.Hogar(
        nombre="Casa de la Playa",
        created_by=test_user_id,
        icono="beach_access",
        codigo_invitacion="PLAYA123",
    )
    db_session.add(target_hogar)
    db_session.commit()

    target_loc = models.Location(
        nombre="Despensa Playa",
        hogar_id=target_hogar.id_hogar,
        es_congelador=False,
    )
    db_session.add(target_loc)
    db_session.commit()

    source_stock = models.InventoryStock(
        hogar_id=test_hogar.id_hogar,
        fk_producto_maestro=test_product.id_producto,
        fk_ubicacion=test_locations["despensa"].id_ubicacion,
        cantidad_actual=5,
        fecha_caducidad=expiry,
        estado_producto="cerrado",
    )
    db_session.add(source_stock)
    db_session.commit()

    # Transfer 2 units
    res = service.transfer_stock_between_households(
        id_stock=source_stock.id_stock,
        current_hogar_id=test_hogar.id_hogar,
        target_hogar_id=target_hogar.id_hogar,
        target_ubicacion_id=target_loc.id_ubicacion,
        cantidad_transferir=2,
    )

    assert res["status"] == "success"
    assert "completada con éxito" in res["message"]
    assert res["cantidad_transferida"] == 2

    # Check source has 3 units left
    db_session.refresh(source_stock)
    assert source_stock.cantidad_actual == 3

    # Check target household has 2 units
    target_stock = (
        db_session.query(models.InventoryStock)
        .filter_by(hogar_id=target_hogar.id_hogar, fk_ubicacion=target_loc.id_ubicacion)
        .first()
    )
    assert target_stock is not None
    assert target_stock.cantidad_actual == 2
