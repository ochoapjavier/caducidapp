# backend/schemas/item.py
from pydantic import BaseModel, ConfigDict, Field, computed_field
from datetime import date

class ItemCreate(BaseModel):
    """Schema para crear un nuevo item en el inventario."""
    product_name: str
    ubicacion_id: int
    cantidad: int
    fecha_caducidad: date

class ItemCreateFromScan(BaseModel):
    """Schema para crear un item desde un escaneo."""
    barcode: str
    product_name: str
    brand: str | None = None
    ubicacion_id: int
    cantidad: int
    fecha_caducidad: date

class Item(BaseModel):
    """Schema para devolver un item del inventario."""
    id_stock: int
    cantidad_actual: int # Coincide con el nombre del atributo en el modelo InventarioStock
    fecha_caducidad: date
    # Estos campos se poblarán desde las relaciones de SQLAlchemy
    producto_maestro: "ProductoMaestroSchema" # Referencia al schema anidado
    ubicacion: "UbicacionSchema" # Referencia al schema anidado
    
    # Configuración para que Pydantic pueda mapear desde objetos SQLAlchemy
    model_config = ConfigDict(from_attributes=True)

class ItemStock(BaseModel):
    """Schema para las alertas, similar a Item pero puede evolucionar por separado."""
    id_stock: int
    cantidad_actual: int # Coincide con el nombre del atributo en el modelo InventarioStock
    fecha_caducidad: date
    producto_maestro: "ProductoMaestroSchema" # Referencia al schema anidado
    ubicacion: "UbicacionSchema" # Referencia al schema anidado
    
    model_config = ConfigDict(from_attributes=True)


# Schemas auxiliares para las relaciones anidadas
class ProductoMaestroSchema(BaseModel):
    id_producto: int
    nombre: str
    marca: str | None = None
    model_config = ConfigDict(from_attributes=True)

class UbicacionSchema(BaseModel):
    nombre: str
    model_config = ConfigDict(from_attributes=True)
    id_ubicacion: int

Item.model_rebuild()
ItemStock.model_rebuild()