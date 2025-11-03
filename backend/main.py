# backend/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Importaciones de SQLAlchemy
from database import engine, Base
from repositories import models # Asegura que los modelos se registren

# Creación de las tablas en la base de datos (si no existen)
# En un entorno de producción más complejo, se usarían migraciones (ej. con Alembic)
models.Base.metadata.create_all(bind=engine)

from routers import router as inventory_router

app = FastAPI(title="Core Inventory API (Modular)")

# Configuración de CORS
# En desarrollo, Flutter web puede usar cualquier puerto. Usamos una expresión regular
# para permitir cualquier puerto en localhost.
# En producción, deberías añadir aquí el dominio de tu aplicación web.
origins = [
    "http://localhost", # Para pruebas locales directas
]

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r'http://localhost:\d+', # Permite http://localhost:CUALQUIER_PUERTO
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Montamos el router principal de la API
app.include_router(inventory_router, prefix="/api/v1")

@app.get("/")
def read_root():
    return {"status": "Core API Running", "message": "API lista y refactorizada con SQLAlchemy ORM."}
