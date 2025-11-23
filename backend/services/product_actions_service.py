# backend/services/product_actions_service.py
"""
Service for product state management actions:
- Opening sealed products
- Freezing products
- Unfreezing products
- Relocating products
"""
from sqlalchemy.orm import Session
from datetime import date, timedelta
from fastapi import HTTPException
from repositories.stock_repository import StockRepository
from repositories.location_repository import LocationRepository
from models import InventoryStock


class ProductActionsService:
    def __init__(self, db: Session):
        self.db = db
        self.stock_repo = StockRepository(db)
        self.location_repo = LocationRepository(db)

    def open_product(
        self,
        stock_id: int,
        user_id: str,
        cantidad: int,
        nueva_ubicacion_id: int | None,
        mantener_fecha_caducidad: bool,
        dias_vida_util: int
    ) -> dict:
        """
        Opens sealed units of a product.
        
        Steps:
        1. Validate original item exists and has enough units
        2. Validate original item is 'cerrado' (sealed)
        3. Decrement quantity from original item (or delete if reaches 0)
        4. Create new item with estado='abierto' and expiration date (kept or recalculated)
        """
        # Get original item
        original_item = self.stock_repo.get_stock_item_by_id_and_user(stock_id, user_id)
        if not original_item:
            raise HTTPException(status_code=404, detail="Item de stock no encontrado")
        
        # Validate quantity
        if original_item.cantidad_actual < cantidad:
            raise HTTPException(
                status_code=400,
                detail=f"Solo hay {original_item.cantidad_actual} unidades disponibles"
            )
        
        # Validate state (can only open sealed products)
        if original_item.estado_producto != 'cerrado':
            raise HTTPException(
                status_code=400,
                detail=f"Solo se pueden abrir productos cerrados. Estado actual: {original_item.estado_producto}"
            )
        
        # Determine target location
        target_location_id = nueva_ubicacion_id if nueva_ubicacion_id else original_item.fk_ubicacion
        
        # Validate location exists and belongs to user
        location = self.location_repo.get_location_by_id_and_user(target_location_id, user_id)
        if not location:
            raise HTTPException(status_code=404, detail="Ubicación no encontrada")
        
        # Determine expiration date
        today = date.today()
        if mantener_fecha_caducidad:
            new_expiration = original_item.fecha_caducidad
            expiry_message = f"Fecha de caducidad mantenida: {new_expiration}"
        else:
            new_expiration = today + timedelta(days=dias_vida_util)
            expiry_message = f"Nueva fecha de caducidad: {new_expiration} ({dias_vida_util} días desde apertura)"
        
        # Update original item quantity
        original_item.cantidad_actual -= cantidad
        if original_item.cantidad_actual == 0:
            self.stock_repo.delete_stock_item(original_item)
        else:
            self.db.commit()
        
        # Create new opened item
        new_item = InventoryStock(
            user_id=user_id,
            fk_producto_maestro=original_item.fk_producto_maestro,
            fk_ubicacion=target_location_id,
            cantidad_actual=cantidad,
            fecha_caducidad=new_expiration,
            estado_producto='abierto',
            fecha_apertura=today,
            dias_caducidad_abierto=dias_vida_util
        )
        self.db.add(new_item)
        self.db.commit()
        self.db.refresh(new_item)
        
        return {
            "message": f"Producto abierto exitosamente. {expiry_message}",
            "item_original_id": stock_id if original_item.cantidad_actual > 0 else None,
            "item_nuevo_id": new_item.id_stock,
            "cantidad_procesada": cantidad
        }

    def freeze_product(
        self,
        stock_id: int,
        user_id: str,
        cantidad: int,
        ubicacion_congelador_id: int
    ) -> dict:
        """
        Freezes units of a product to pause expiration.
        
        Steps:
        1. Validate original item exists and has enough units
        2. Validate original item is NOT already frozen
        3. Validate freezer location exists
        4. Decrement quantity from original item
        5. Create new item with estado='congelado'
        """
        # Get original item
        original_item = self.stock_repo.get_stock_item_by_id_and_user(stock_id, user_id)
        if not original_item:
            raise HTTPException(status_code=404, detail="Item de stock no encontrado")
        
        # Validate quantity
        if original_item.cantidad_actual < cantidad:
            raise HTTPException(
                status_code=400,
                detail=f"Solo hay {original_item.cantidad_actual} unidades disponibles"
            )
        
        # Validate state (cannot freeze already frozen products)
        if original_item.estado_producto == 'congelado':
            raise HTTPException(
                status_code=400,
                detail="Este producto ya está congelado"
            )
        
        # Validate freezer location
        freezer_location = self.location_repo.get_location_by_id_and_user(ubicacion_congelador_id, user_id)
        if not freezer_location:
            raise HTTPException(status_code=404, detail="Ubicación del congelador no encontrada")
        
        today = date.today()
        
        # Update original item quantity
        original_item.cantidad_actual -= cantidad
        if original_item.cantidad_actual == 0:
            self.stock_repo.delete_stock_item(original_item)
        else:
            self.db.commit()
        
        # Create new frozen item
        new_item = InventoryStock(
            user_id=user_id,
            fk_producto_maestro=original_item.fk_producto_maestro,
            fk_ubicacion=ubicacion_congelador_id,
            cantidad_actual=cantidad,
            fecha_caducidad=original_item.fecha_caducidad,  # Keep original date for reference
            estado_producto='congelado',
            fecha_congelacion=today
        )
        self.db.add(new_item)
        self.db.commit()
        self.db.refresh(new_item)
        
        return {
            "message": "Producto congelado exitosamente",
            "item_original_id": stock_id if original_item.cantidad_actual > 0 else None,
            "item_nuevo_id": new_item.id_stock,
            "cantidad_procesada": cantidad
        }

    def unfreeze_product(
        self,
        stock_id: int,
        user_id: str,
        nueva_ubicacion_id: int,
        dias_vida_util: int
    ) -> dict:
        """
        Unfreezes a product and sets short expiration.
        
        Steps:
        1. Validate item exists and is frozen
        2. Validate new location
        3. Update item: change state to 'abierto', new expiration, new location
        """
        # Get frozen item
        frozen_item = self.stock_repo.get_stock_item_by_id_and_user(stock_id, user_id)
        if not frozen_item:
            raise HTTPException(status_code=404, detail="Item de stock no encontrado")
        
        # Validate state
        if frozen_item.estado_producto != 'congelado':
            raise HTTPException(
                status_code=400,
                detail=f"Solo se pueden descongelar productos congelados. Estado actual: {frozen_item.estado_producto}"
            )
        
        # Validate new location
        new_location = self.location_repo.get_location_by_id_and_user(nueva_ubicacion_id, user_id)
        if not new_location:
            raise HTTPException(status_code=404, detail="Ubicación no encontrada")
        
        # Calculate new expiration (unfrozen products expire quickly)
        today = date.today()
        new_expiration = today + timedelta(days=dias_vida_util)
        
        # Update item
        frozen_item.estado_producto = 'abierto'  # Mark as open since it needs quick consumption
        frozen_item.fecha_apertura = today
        frozen_item.fecha_caducidad = new_expiration
        frozen_item.fk_ubicacion = nueva_ubicacion_id
        frozen_item.dias_caducidad_abierto = dias_vida_util
        # Keep fecha_congelacion for history
        
        self.db.commit()
        self.db.refresh(frozen_item)
        
        return {
            "message": "Producto descongelado exitosamente. ¡Consumir pronto!",
            "item_original_id": frozen_item.id_stock,
            "item_nuevo_id": frozen_item.id_stock,
            "cantidad_procesada": frozen_item.cantidad_actual
        }

    def relocate_product(
        self,
        stock_id: int,
        user_id: str,
        cantidad: int,
        nueva_ubicacion_id: int
    ) -> dict:
        """
        Moves units to a different location without changing state.
        
        Steps:
        1. Validate original item exists and has enough units
        2. Validate new location
        3. Check if item with same characteristics exists in new location
        4. If exists: merge quantities
        5. If not: create new item
        6. Decrement original item
        """
        # Get original item
        original_item = self.stock_repo.get_stock_item_by_id_and_user(stock_id, user_id)
        if not original_item:
            raise HTTPException(status_code=404, detail="Item de stock no encontrado")
        
        # Validate quantity
        if original_item.cantidad_actual < cantidad:
            raise HTTPException(
                status_code=400,
                detail=f"Solo hay {original_item.cantidad_actual} unidades disponibles"
            )
        
        # Validate same location
        if original_item.fk_ubicacion == nueva_ubicacion_id:
            raise HTTPException(
                status_code=400,
                detail="El producto ya está en esa ubicación"
            )
        
        # Validate new location
        new_location = self.location_repo.get_location_by_id_and_user(nueva_ubicacion_id, user_id)
        if not new_location:
            raise HTTPException(status_code=404, detail="Ubicación no encontrada")
        
        # Check if equivalent item exists in target location
        existing_item = self.db.query(InventoryStock).filter(
            InventoryStock.user_id == user_id,
            InventoryStock.fk_producto_maestro == original_item.fk_producto_maestro,
            InventoryStock.fk_ubicacion == nueva_ubicacion_id,
            InventoryStock.fecha_caducidad == original_item.fecha_caducidad,
            InventoryStock.estado_producto == original_item.estado_producto
        ).first()
        
        # Update original item quantity
        original_item.cantidad_actual -= cantidad
        if original_item.cantidad_actual == 0:
            self.stock_repo.delete_stock_item(original_item)
        else:
            self.db.commit()
        
        new_item_id = None
        if existing_item:
            # Merge into existing item
            existing_item.cantidad_actual += cantidad
            self.db.commit()
            new_item_id = existing_item.id_stock
            message = f"Producto movido y fusionado con item existente"
        else:
            # Create new item in target location
            new_item = InventoryStock(
                user_id=user_id,
                fk_producto_maestro=original_item.fk_producto_maestro,
                fk_ubicacion=nueva_ubicacion_id,
                cantidad_actual=cantidad,
                fecha_caducidad=original_item.fecha_caducidad,
                estado_producto=original_item.estado_producto,
                fecha_apertura=original_item.fecha_apertura,
                fecha_congelacion=original_item.fecha_congelacion,
                dias_caducidad_abierto=original_item.dias_caducidad_abierto
            )
            self.db.add(new_item)
            self.db.commit()
            self.db.refresh(new_item)
            new_item_id = new_item.id_stock
            message = "Producto reubicado exitosamente"
        
        return {
            "message": message,
            "item_original_id": stock_id if original_item.cantidad_actual > 0 else None,
            "item_nuevo_id": new_item_id,
            "cantidad_procesada": cantidad
        }
