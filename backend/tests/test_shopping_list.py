"""Tests for shopping list router and services with security and inventory integration."""
from datetime import date, timedelta
import pytest
import models


def test_add_and_aggregate_shopping_item(client, test_hogar):
    """Adding an item creates it, and adding the same name again aggregates quantity."""
    # 1. Add item
    res = client.post(
        f"/api/v1/shopping-list/hogar/{test_hogar.id_hogar}",
        json={"producto_nombre": "Manzanas Fuji", "cantidad": 2},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["producto_nombre"] == "Manzanas Fuji"
    assert data["cantidad"] == 2
    item_id = data["id"]

    # 2. Add identical item -> aggregates quantity to 5
    res2 = client.post(
        f"/api/v1/shopping-list/hogar/{test_hogar.id_hogar}",
        json={"producto_nombre": "Manzanas Fuji", "cantidad": 3},
    )
    assert res2.status_code == 201
    data2 = res2.json()
    assert data2["id"] == item_id
    assert data2["cantidad"] == 5


def test_get_shopping_list_for_household(client, test_hogar):
    """Get all shopping list items for the household."""
    client.post(
        f"/api/v1/shopping-list/hogar/{test_hogar.id_hogar}",
        json={"producto_nombre": "Pan de Molde", "cantidad": 1},
    )

    res = client.get(f"/api/v1/shopping-list/hogar/{test_hogar.id_hogar}")
    assert res.status_code == 200
    items = res.json()
    assert any(i["producto_nombre"] == "Pan de Molde" for i in items)


def test_move_shopping_item_to_inventory(client, test_hogar, test_locations, db_session):
    """Moving a bought shopping item removes it from list and adds it to stock inventory."""
    # 1. Add item to shopping list
    res = client.post(
        f"/api/v1/shopping-list/hogar/{test_hogar.id_hogar}",
        json={"producto_nombre": "Yogur Natural", "cantidad": 4},
    )
    item_id = res.json()["id"]

    # 2. Move to inventory
    target_date = (date.today() + timedelta(days=15)).strftime("%Y-%m-%d")
    move_res = client.post(
        f"/api/v1/shopping-list/{item_id}/to-inventory"
        f"?ubicacion_id={test_locations['nevera'].id_ubicacion}&fecha_caducidad={target_date}"
    )
    assert move_res.status_code == 200
    stock_id = move_res.json()["stock_id"]

    # 3. Verify item is removed from shopping list
    deleted_check = db_session.query(models.ShoppingListItem).filter_by(id=item_id).first()
    assert deleted_check is None

    # 4. Verify item exists in inventory stock
    stock_check = db_session.query(models.InventoryStock).filter_by(id_stock=stock_id).first()
    assert stock_check is not None
    assert stock_check.cantidad_actual == 4
    assert stock_check.estado_producto == "cerrado"
    assert str(stock_check.fecha_caducidad) == target_date


def test_shopping_list_forbidden_for_non_member(client, db_session):
    """A user who is not a member of a household must be rejected with 403."""
    # Create another household with a different creator
    foreign_hogar = models.Hogar(
        nombre="Casa Ajena",
        created_by="other-user-999",
        icono="home",
        codigo_invitacion="AJEN9999",
    )
    db_session.add(foreign_hogar)
    db_session.commit()

    res = client.get(f"/api/v1/shopping-list/hogar/{foreign_hogar.id_hogar}")
    assert res.status_code == 403

