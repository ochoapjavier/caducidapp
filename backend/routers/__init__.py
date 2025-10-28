# backend/routers/__init__.py

from fastapi import APIRouter
from . import ubicaciones, stock, alertas

router = APIRouter()

router.include_router(ubicaciones.router, tags=["Ubicaciones"])
router.include_router(stock.router, tags=["Stock"])
router.include_router(alertas.router, tags=["Alertas"])
