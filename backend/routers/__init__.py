from fastapi import APIRouter
from . import locations, stock, alerts, products, product_actions, hogares

# Este es el router principal que será incluido en main.py.
# Manejará el prefijo "/inventory" para todas las rutas relacionadas.
router = APIRouter(prefix="/inventory")

# Incluimos los routers individuales. Los prefijos aquí se añadirán
# después del prefijo "/inventory".
router.include_router(locations.router, prefix="/ubicaciones", tags=["Locations"])
router.include_router(stock.router, prefix="/stock", tags=["Stock"])
router.include_router(alerts.router, prefix="/alertas", tags=["Alerts"])
router.include_router(products.router, prefix="/products", tags=["Products"])
router.include_router(product_actions.router, tags=["Product Actions"])  # No prefix, already in router
router.include_router(hogares.router)  # Prefix defined in router itself (/hogares)