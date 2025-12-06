# backend/schemas/item.py
from pydantic import BaseModel, ConfigDict
from datetime import date

class StockItemCreate(BaseModel):
    """Request: crear un nuevo item de stock en el inventario."""
    product_name: str
    product_id: int | None = None
    barcode: str | None = None
    brand: str | None = None
    image_url: str | None = None
    ubicacion_id: int
    cantidad: int
    fecha_caducidad: date

class StockItemCreateFromScan(BaseModel):
    """Request: crear un item de stock desde un escaneo."""
    barcode: str
    product_name: str
    brand: str | None = None
    image_url: str | None = None
    ubicacion_id: int
    cantidad: int
    fecha_caducidad: date

class StockItem(BaseModel):
    """Response: item de stock en el inventario."""
    id_stock: int
    cantidad_actual: int
    fecha_caducidad: date
    # Nuevos campos para gestión de estados
    estado_producto: str = 'cerrado'  # 'cerrado', 'abierto', 'congelado', 'descongelado'
    fecha_apertura: date | None = None
    fecha_congelacion: date | None = None
    fecha_descongelacion: date | None = None
    dias_caducidad_abierto: int | None = None
    # Relaciones anidadas
    producto_maestro: "ProductSchema"
    ubicacion: "LocationSchema"
    
    # Configuración para que Pydantic pueda mapear desde objetos SQLAlchemy
    model_config = ConfigDict(from_attributes=True)

class StockAlertItem(BaseModel):
    """Response: item de stock para alertas (puede evolucionar por separado)."""
    id_stock: int
    cantidad_actual: int
    fecha_caducidad: date
    estado_producto: str = 'cerrado'
    fecha_apertura: date | None = None
    fecha_congelacion: date | None = None
    fecha_descongelacion: date | None = None
    producto_maestro: "ProductSchema"
    ubicacion: "LocationSchema"
    
    model_config = ConfigDict(from_attributes=True)


# Schemas auxiliares para las relaciones anidadas
class ProductSchema(BaseModel):
    id_producto: int
    nombre: str
    marca: str | None = None
    image_url: str | None = None
    model_config = ConfigDict(from_attributes=True)

class LocationSchema(BaseModel):
    nombre: str
    model_config = ConfigDict(from_attributes=True)
    id_ubicacion: int

StockItem.model_rebuild()
StockAlertItem.model_rebuild()