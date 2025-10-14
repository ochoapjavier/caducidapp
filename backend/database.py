# backend/database.py

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Obtener la URL de conexión del entorno (definida en docker-compose.yml)
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/receipt_inventory")

# Creamos el motor de la base de datos
engine = create_engine(DATABASE_URL)

# Creamos una sesión local
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Función de dependencia para obtener la sesión de DB (reutilizable en routers)
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()