-- Script de Migración para Supabase / PostgreSQL (Sistema de Valoraciones de Productos)
-- Fecha: 2026-08-21
-- Propósito: Crear la tabla producto_valoracion e índices asociados para soporte de ratings, notas y favoritos.

-- 1. Crear la tabla de valoraciones por producto y usuario dentro del hogar
CREATE TABLE IF NOT EXISTS producto_valoracion (
    id_valoracion SERIAL PRIMARY KEY,
    fk_producto INTEGER NOT NULL REFERENCES producto_maestro(id_producto) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL,
    hogar_id INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    puntuacion NUMERIC(2,1) NOT NULL CHECK (puntuacion >= 1.0 AND puntuacion <= 5.0),
    es_favorito BOOLEAN NOT NULL DEFAULT FALSE,
    nota TEXT,
    tags VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);


-- 2. Asegurar que un usuario solo tenga una entrada de valoración por producto
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'producto_valoracion_user_unique'
    ) THEN
        ALTER TABLE producto_valoracion 
        ADD CONSTRAINT producto_valoracion_user_unique UNIQUE (fk_producto, user_id);
    END IF;
END $$;

-- 3. Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_producto_valoracion_producto ON producto_valoracion(fk_producto);
CREATE INDEX IF NOT EXISTS idx_producto_valoracion_hogar ON producto_valoracion(hogar_id);
CREATE INDEX IF NOT EXISTS idx_producto_valoracion_user ON producto_valoracion(user_id);
CREATE INDEX IF NOT EXISTS idx_producto_valoracion_favorito ON producto_valoracion(hogar_id, user_id, es_favorito);

-- 4. Activar Row Level Security (RLS)
ALTER TABLE producto_valoracion ENABLE ROW LEVEL SECURITY;

SELECT 'Tabla producto_valoracion creada exitosamente' AS status;
