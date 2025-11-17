from pydantic import BaseModel
from datetime import date


class StockUpdate(BaseModel):
    """Request: actualizar campos de un item de stock.

    - product_name / brand actualizan el producto maestro asociado
    - fecha_caducidad y cantidad_actual actualizan la fila de stock
    - ubicacion_id permite mover el item a otra ubicación
    """
    product_name: str | None = None
    brand: str | None = None
    fecha_caducidad: date | None = None
    cantidad_actual: int | None = None
    ubicacion_id: int | None = None


class StockRemove(BaseModel):
    """Request: eliminar una cantidad específica de un item de stock."""
    id_stock: int
    cantidad: int
