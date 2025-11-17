# backend/repositories/__init__.py

from .location_repository import LocationRepository
from .product_repository import ProductRepository
from .stock_repository import StockRepository

__all__ = [
    "LocationRepository",
    "ProductRepository",
    "StockRepository",
]
