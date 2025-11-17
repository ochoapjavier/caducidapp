from pydantic import BaseModel

class ProductUpdate(BaseModel):
    nombre: str
    marca: str | None = None
