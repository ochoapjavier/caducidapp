# backend/schemas/__init__.py

from .location import Location, LocationCreate
from .item import (
    StockItemCreate, StockItemCreateFromScan, StockItem, StockAlertItem,
    ProductSchema, LocationSchema,
)
from .alert import AlertResponse
from .stock_update import StockUpdate, StockRemove
from .product_update import ProductUpdate

__all__ = [
    "Location",
    "LocationCreate",
    "StockItemCreate",
    "StockItemCreateFromScan",
    "StockItem",
    "StockAlertItem",
    "AlertResponse",
    "StockUpdate",
    "StockRemove",
    "ProductSchema",
    "LocationSchema",
    "ProductUpdate",
]
