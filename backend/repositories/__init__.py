# backend/repositories/__init__.py

from .ubicacion_repository import UbicacionRepository
from .producto_maestro_repository import ProductoMaestroRepository
from .stock_repository import StockRepository

__all__ = [
    "UbicacionRepository",
    "ProductoMaestroRepository",
    "StockRepository",
]
