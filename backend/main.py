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
origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Montamos el router principal de la API
app.include_router(inventory_router, prefix="/api/v1")

@app.get("/")
def read_root():
    return {"status": "Core API Running", "message": "API lista y refactorizada con SQLAlchemy ORM."}
