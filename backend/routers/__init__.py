# backend/routers/__init__.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from schemas import UbicacionCreate, ItemCreate, AlertaResponse
from services import InventoryService

router = APIRouter()

# Dependencia para crear el servicio, inyectando la sesión de DB
def get_inventory_service(db: Session = Depends(get_db)):
    return InventoryService(db)

# HU2: Ubicaciones
@router.post("/ubicaciones/")
def create_ubicacion_endpoint(
    data: UbicacionCreate, 
    service: InventoryService = Depends(get_inventory_service)
):
    return service.create_new_ubicacion(data)

@router.get("/ubicaciones/")
def get_ubicaciones_endpoint(
    service: InventoryService = Depends(get_inventory_service)
):
    return service.get_all_ubicaciones()

@router.delete("/ubicaciones/{id_ubicacion}", status_code=200)
def delete_ubicacion_endpoint(
    id_ubicacion: int,
    service: InventoryService = Depends(get_inventory_service)
):
    # El servicio se encarga de la lógica y de lanzar excepciones si algo va mal
    return service.delete_ubicacion(id_ubicacion)

@router.put("/ubicaciones/{id_ubicacion}", status_code=200)
def update_ubicacion_endpoint(
    id_ubicacion: int,
    ubicacion_data: UbicacionCreate, # Reutilizamos el schema de creación
    service: InventoryService = Depends(get_inventory_service)
):
    return service.update_ubicacion(id_ubicacion, ubicacion_data.nombre)

# HU3: Ingreso Manual de Stock
@router.post("/inventario/")
def add_manual_stock_endpoint(
    data: ItemCreate,
    service: InventoryService = Depends(get_inventory_service)
):
    return service.process_manual_stock(data)

# HU4: Dashboard de Caducidades
@router.get("/alertas/proxima-semana", response_model=AlertaResponse)
def get_alertas_endpoint(
    service: InventoryService = Depends(get_inventory_service)
):
    # Llama al servicio pidiendo alertas de los próximos 7 días
    return service.get_expiring_alerts(days=7)