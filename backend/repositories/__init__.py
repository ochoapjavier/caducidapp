# backend/repositories/__init__.py

from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import date, timedelta
from typing import List, Dict, Any, Optional

class InventoryRepository:
    """
    Gestiona el acceso directo a la base de datos para todas las entidades
    del inventario (Ubicacion, ProductoMaestro, InventarioStock).
    """

    def __init__(self, db: Session):
        self.db = db

    def create_ubicacion(self, nombre: str) -> int:
        # Definimos los parámetros
        params = {"nombre": nombre} 
        query = text(
            "INSERT INTO Ubicacion (nombre) VALUES (:nombre) RETURNING id_ubicacion"
        )
        # CORRECCIÓN: Usamos params=params para consistencia y evitar errores futuros
        result = self.db.execute(query, params=params) 
        self.db.commit()
        # Nota: Retorna el ID de la nueva ubicación.
        return result.scalar_one() 
        
    def get_ubicacion_id_by_name(self, nombre: str) -> Optional[int]:
        query = text("SELECT id_ubicacion FROM Ubicacion WHERE nombre = :nombre")
        return self.db.execute(query, {"nombre": nombre}).scalar_one_or_none()

    def get_all_ubicaciones(self) -> List[dict]:
        query = text("SELECT id_ubicacion, nombre FROM Ubicacion ORDER BY nombre")
        ubicaciones = self.db.execute(query).fetchall()
        # CORRECCIÓN: La variable correcta es 'ubicaciones', no 'resultados'
        return [{"id_ubicacion": row[0], "nombre": row[1]} for row in ubicaciones] 

    def is_ubicacion_in_use(self, id_ubicacion: int) -> bool:
        """Verifica si una ubicación está siendo usada en la tabla de stock."""
        query = text("SELECT 1 FROM InventarioStock WHERE fk_ubicacion = :id_ubicacion LIMIT 1")
        result = self.db.execute(query, {"id_ubicacion": id_ubicacion}).scalar_one_or_none()
        return result is not None

    def delete_ubicacion_by_id(self, id_ubicacion: int) -> int:
        """Elimina una ubicación por su ID y retorna el número de filas afectadas."""
        # Primero, verificamos si la ubicación existe para evitar errores silenciosos
        # y asegurar que el ID es válido antes de proceder.
        check_query = text("SELECT id_ubicacion FROM Ubicacion WHERE id_ubicacion = :id_ubicacion")
        ubicacion_exists = self.db.execute(check_query, {"id_ubicacion": id_ubicacion}).scalar_one_or_none()

        if ubicacion_exists is None:
            return 0 # Retornamos 0 si no se encontró la ubicación para eliminar

        # Si existe, procedemos a eliminarla
        delete_query = text("DELETE FROM Ubicacion WHERE id_ubicacion = :id_ubicacion")
        result = self.db.execute(delete_query, {"id_ubicacion": id_ubicacion})
        self.db.commit()
        return result.rowcount 

    def update_ubicacion_by_id(self, id_ubicacion: int, new_name: str) -> int:
        """Actualiza el nombre de una ubicación por su ID."""
        query = text("UPDATE Ubicacion SET nombre = :new_name WHERE id_ubicacion = :id_ubicacion")
        result = self.db.execute(query, {"new_name": new_name, "id_ubicacion": id_ubicacion})
        self.db.commit()
        return result.rowcount

    def get_or_create_producto_maestro(self, nombre: str) -> int:
        # 1. Definir el diccionario de parámetros una vez
        params = {"nombre": nombre}

         # 2. Buscar Producto Maestro
        # Usamos params=params para forzar el bindeo de los parámetros.
        producto_id = self.db.execute(
            text("SELECT id_producto FROM ProductoMaestro WHERE nombre = :nombre"),
            params=params # <--- CAMBIO CRÍTICO
        ).scalar_one_or_none()
        
        if producto_id is None:
            # 3. Crear Producto Maestro (CORRECCIÓN APLICADA AQUÍ)
            result = self.db.execute(
                text("INSERT INTO ProductoMaestro (nombre) VALUES (:nombre) RETURNING id_producto"),
                params=params # <--- CAMBIO CRÍTICO
            )
            producto_id = result.scalar_one()
            self.db.commit() 
            
        return producto_id

    def add_stock_item(self, prod_id: int, ubic_id: int, cantidad: int, fecha: date) -> int:
        stock_query = text("""
            INSERT INTO InventarioStock 
            (fk_producto_maestro, fk_ubicacion, cantidad_actual, fecha_caducidad, estado)
            VALUES (:prod_id, :ubic_id, :cant, :fecha, 'Activo')
            RETURNING id_stock
        """)
        
        result = self.db.execute(stock_query, {
            "prod_id": prod_id,
            "ubic_id": ubic_id,
            "cant": cantidad,
            "fecha": fecha
        })
        self.db.commit()
        return result.scalar_one()

    def get_alertas_caducidad(self, days: int = 7) -> List:
        fecha_inicio = date.today()
        fecha_fin = fecha_inicio + timedelta(days=days)
        
        # Esta es la consulta central del MVP [1, 2]
        query = f"""
        SELECT 
            pm.nombre AS producto, 
            i.cantidad_actual, 
            i.fecha_caducidad, 
            u.nombre AS ubicacion
        FROM InventarioStock i
        JOIN ProductoMaestro pm ON i.fk_producto_maestro = pm.id_producto
        JOIN Ubicacion u ON i.fk_ubicacion = u.id_ubicacion
        WHERE 
            i.estado = 'Activo' AND 
            i.fecha_caducidad BETWEEN '{fecha_inicio}' AND '{fecha_fin}'
        ORDER BY i.fecha_caducidad ASC;
        """
        
        resultados = self.db.execute(text(query)).fetchall()
        
        # Transforma el resultado de la DB a una lista de diccionarios
        items = []
        for row in resultados:
            items.append({
                "producto": row[0],
                "cantidad": row[1],
                "fecha_caducidad": row[2].isoformat(),  # Formato de fecha estándar
                "ubicacion": row[3]
            })
            
        # CORRECCIÓN: Retornar solo la lista de ítems, no el diccionario envuelto
        return items