from fastapi import APIRouter
from . import ubicaciones, stock, alertas

# Este es el router principal que será incluido en main.py.
# Manejará el prefijo "/inventory" para todas las rutas relacionadas.
router = APIRouter(prefix="/inventory")

# Incluimos los routers individuales. Los prefijos aquí se añadirán
# después del prefijo "/inventory".
router.include_router(ubicaciones.router, prefix="/ubicaciones", tags=["Ubicaciones"])
router.include_router(stock.router, prefix="/stock", tags=["Stock"])
router.include_router(alertas.router, prefix="/alertas", tags=["Alertas"])