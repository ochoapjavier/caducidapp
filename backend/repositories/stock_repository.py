# backend/repositories/stock_repository.py
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import date, timedelta
from typing import List

class StockRepository:
    def __init__(self, db: Session):
        self.db = db

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
        
        items = []
        for row in resultados:
            items.append({
                "producto": row[0],
                "cantidad": row[1],
                "fecha_caducidad": row[2].isoformat(),
                "ubicacion": row[3]
            })
            
        return items
