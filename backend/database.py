# backend/database.py

import os
from sqlalchemy import NullPool, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Obtener la URL de conexión del entorno (definida en docker-compose.yml)
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/receipt_inventory")

# Creamos el motor de la base de datos con la opción pool_pre_ping.
# Esto verifica que la conexión a la base de datos esté activa antes de usarla,
# lo que evita errores de "conexión cerrada" cuando el servicio se despierta
# después de un período de inactividad (típico en los free tiers de Render).
engine = create_engine(
    DATABASE_URL,
    poolclass=NullPool,
    pool_pre_ping=True,
)

Base = declarative_base()

# Creamos una sesión local
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Función de dependencia para obtener la sesión de DB (reutilizable en routers)
def get_db():
    db = SessionLocal()
    try:
        yield db
    except Exception:
        db.rollback() # Rollback en caso de excepción
        raise
    finally:
        db.close()