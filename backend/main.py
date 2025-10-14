# backend/main.py (FINAL)

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import get_db
from routers import router as inventory_router

app = FastAPI(title="Core Inventory API (Modular)")

# Lista de orígenes permitidos para CORS.
# Durante el desarrollo, usar "*" es lo más sencillo para permitir
# que tu app Flutter (web o móvil) se conecte sin problemas.
# En un entorno de producción, deberías restringir esto a los dominios específicos de tu frontend.
origins = [
    "*"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins, # Lista de orígenes permitidos
    allow_credentials=True, 
    allow_methods=["*"],    
    allow_headers=["*"],    
)

# Montamos el router de inventario bajo un prefijo
app.include_router(inventory_router, prefix="/api/v1/inventory")

@app.get("/")
def read_root():
    return {"status": "Core API Running", "message": "API Modular lista para el Sprint 1"}

# Mantenemos el check de DB fuera del router para simplificar la verificación de estado general
@app.get("/db-status")
def check_db_status(db: Session = Depends(get_db)):
    """Verifica si la API puede conectarse a PostgreSQL"""
    try:
        db.execute(text("SELECT 1"))
        return {"db_status": "Connected", "message": "Conexión a PostgreSQL exitosa."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error de conexión a DB: {e}")