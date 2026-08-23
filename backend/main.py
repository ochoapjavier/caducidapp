# backend/main.py
from fastapi import FastAPI, Response, status
from fastapi.middleware.cors import CORSMiddleware

# Importaciones de SQLAlchemy
from database import engine, Base
import models  # Asegura que los modelos se registren

# Creación de las tablas en la base de datos (si no existen)
# En un entorno de producción más complejo, se usarían migraciones (ej. con Alembic)
Base.metadata.create_all(bind=engine)

from routers import router as inventory_router
from routers import notifications as notifications_router
from routers import shopping_list as shopping_list_router
from routers import receipts as receipts_router
from routers import supermercados as supermercados_router

app = FastAPI(title="Core Inventory API (Modular)")

# Configuración de CORS amplia para desarrollo y producción (Vercel, Localhost, Móvil)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Montamos el router principal de la API
app.include_router(inventory_router, prefix="/api/v1")
app.include_router(notifications_router.router, prefix="/api/v1/notifications", tags=["Notifications"])
app.include_router(shopping_list_router.router, prefix="/api/v1", tags=["Shopping List"])
app.include_router(receipts_router.router, prefix="/api/v1/inventory/receipts", tags=["Receipts"])
app.include_router(supermercados_router.router, prefix="/api/v1/inventory/supermercados", tags=["Supermercados"])

@app.get("/")
def read_root():
    return {"status": "Core API Running", "message": "API lista y refactorizada con SQLAlchemy ORM."}

@app.api_route(
    "/health", 
    methods=["GET", "HEAD"],
    status_code=status.HTTP_200_OK,
    summary="Health Check Endpoint",
    description="Endpoint simple para verificar que la API está activa. Responde a GET y HEAD.",
    tags=["Health"]
)
def health_check():
    """
    Este endpoint es utilizado por servicios de monitoreo
    para mantener el servicio activo.
    Devuelve una respuesta vacía con código 200 OK.
    """
    return Response(status_code=status.HTTP_200_OK)