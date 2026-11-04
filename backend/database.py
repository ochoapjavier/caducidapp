# backend/database.py

import os
from sqlalchemy import NullPool, create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Obtener la URL de conexión del entorno
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/receipt_inventory")

# Normalizar esquema a postgresql+psycopg2:// si viene como postgresql:// o postgres://
# Esto garantiza compatibilidad universal entre Render, Supabase, Docker y SQLAlchemy 2.0
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg2://", 1)
elif DATABASE_URL.startswith("postgresql://") and not DATABASE_URL.startswith("postgresql+"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://", 1)

# Creamos el motor de la base de datos con pool_pre_ping.
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
        db.rollback()  # Rollback en caso de excepción
        raise
    finally:
        db.close()
