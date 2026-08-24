# backend/schemas/product_rating.py
from pydantic import BaseModel, Field
from datetime import datetime

class ProductRatingBase(BaseModel):
    puntuacion: float = Field(..., ge=1.0, le=5.0, description="Puntuación de 1.0 a 5.0 estrellas")
    es_favorito: bool = False
    nota: str | None = None
    tags: str | None = None  # Lista separada por comas de etiquetas


class ProductRatingCreate(ProductRatingBase):
    pass


class ProductRatingSchema(ProductRatingBase):
    id_valoracion: int
    fk_producto: int
    user_id: str
    hogar_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CatalogProductSchema(BaseModel):
    id_producto: int
    barcode: str | None = None
    nombre: str
    marca: str | None = None
    image_url: str | None = None
    dias_consumo_abierto: int | None = None
    hogar_id: int
    
    # Métricas agregadas
    stock_actual: int = 0
    rating_promedio: float | None = None
    total_valoraciones: int = 0
    
    # Datos específicos del usuario actual
    mi_puntuacion: float | None = None
    es_favorito: bool = False
    mi_nota: str | None = None
    mis_tags: str | None = None

    # Datos Nutricionales (OpenFoodFacts / MyRealFood / Nutri-Score)
    nova_group: int | None = None
    nutriscore_grade: str | None = None
    alergenos: str | None = None
    aditivos_count: int = 0
    semaforo_nutricional: str | None = None
    nutrientes_100g: str | None = None

    class Config:

        from_attributes = True
