# backend/services/__init__.py

from fastapi import HTTPException
from sqlalchemy.orm import Session
from datetime import date
from repositories import InventoryRepository
from schemas import ItemCreate, UbicacionCreate, AlertaResponse, ItemStock

class InventoryService:
    """
    Contiene la lógica de negocio y utiliza el repositorio para la persistencia.
    """
    def __init__(self, db: Session):
        self.repo = InventoryRepository(db)

    def create_new_ubicacion(self, ubicacion_data: UbicacionCreate):
        try:
            ubicacion_id = self.repo.create_ubicacion(ubicacion_data.nombre)
            return {"id": ubicacion_id, "nombre": ubicacion_data.nombre}
        except Exception as e:
            # El repositorio ya maneja el rollback, aquí solo relanzamos el error de forma controlada
            raise HTTPException(status_code=400, detail="Error al crear ubicación. El nombre podría ser duplicado.")

    def get_all_ubicaciones(self):
        """Obtiene todas las ubicaciones como una lista de diccionarios"""
        return self.repo.get_all_ubicaciones()

    def delete_ubicacion(self, id_ubicacion: int):
        """Lógica de negocio para eliminar una ubicación."""
        # 1. Verificar si la ubicación está en uso
        if self.repo.is_ubicacion_in_use(id_ubicacion):
            raise HTTPException(
                status_code=409,  # 409 Conflict
                detail="La ubicación no se puede eliminar porque está en uso por uno o más productos en el inventario."
            )
        
        # 2. Si no está en uso, proceder a eliminarla
        deleted_count = self.repo.delete_ubicacion_by_id(id_ubicacion)

        # 3. Verificar si se eliminó algo
        if deleted_count == 0:
            raise HTTPException(
                status_code=404, 
                detail=f"No se encontró una ubicación con el ID {id_ubicacion}."
            )
            
        return {"status": "success", "message": "Ubicación eliminada correctamente."}

    def update_ubicacion(self, id_ubicacion: int, new_name: str):
        """Lógica de negocio para actualizar el nombre de una ubicación."""
        # 1. Validar que el nuevo nombre no esté ya en uso por OTRA ubicación
        existing_id = self.repo.get_ubicacion_id_by_name(new_name)
        if existing_id is not None and existing_id != id_ubicacion:
            raise HTTPException(
                status_code=409,  # Conflict
                detail=f"El nombre '{new_name}' ya está en uso por otra ubicación."
            )

        # 2. Proceder con la actualización
        updated_count = self.repo.update_ubicacion_by_id(id_ubicacion, new_name)

        # 3. Verificar si la actualización fue exitosa
        if updated_count == 0:
            raise HTTPException(
                status_code=404,
                detail=f"No se encontró una ubicación con el ID {id_ubicacion} para actualizar."
            )
            
        return {"status": "success", "message": "Ubicación actualizada correctamente."}

    def process_manual_stock(self, item_data: ItemCreate):
        # Lógica de Negocio: Obtener ID de Maestro (creándolo si es necesario)
        producto_id = self.repo.get_or_create_producto_maestro(item_data.nombre_producto)
        
        # Lógica de Negocio: Validar y obtener ID de Ubicación
        ubicacion_id = self.repo.get_ubicacion_id_by_name(item_data.nombre_ubicacion)

        if ubicacion_id is None:
            raise HTTPException(status_code=404, detail=f"Ubicación '{item_data.nombre_ubicacion}' no encontrada.")

        # Persistencia: Añadir el ítem de stock
        stock_id = self.repo.add_stock_item(
            producto_id, 
            ubicacion_id, 
            item_data.cantidad, 
            item_data.fecha_caducidad
        )
        return {"id_stock": stock_id, "status": "Stock añadido con éxito"}

    def get_expiring_alerts(self, days: int = 7) -> AlertaResponse:
        items_raw = self.repo.get_alertas_caducidad(days)
        
        # Mapeo a esquema Pydantic de salida para asegurar el formato
        items_stock = [
            ItemStock(
                producto=item['producto'],
                cantidad=item['cantidad'],
                fecha_caducidad=date.fromisoformat(item['fecha_caducidad']),
                ubicacion=item['ubicacion']
            ) for item in items_raw
        ]

        return AlertaResponse(productos_proximos_a_caducar=items_stock)