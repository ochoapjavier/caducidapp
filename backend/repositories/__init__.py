# backend/repositories/__init__.py

from .ubicacion_repository import UbicacionRepository
from .producto_repository import ProductoRepository
from .stock_repository import StockRepository

__all__ = [
    "UbicacionRepository",
    "ProductoRepository",
    "StockRepository",
]
