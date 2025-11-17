-- Caducidapp DB Migration: add helpful indexes
-- Date: 2025-11-17
-- Safe to run multiple times; uses IF NOT EXISTS

-- 1) producto_maestro: single-column index for nombre
CREATE INDEX IF NOT EXISTS ix_producto_maestro_nombre
ON producto_maestro (nombre);

-- 2) producto_maestro: composite index (user_id, nombre)
CREATE INDEX IF NOT EXISTS ix_producto_user_nombre
ON producto_maestro (user_id, nombre);

-- 3) inventario_stock: single-column index for fecha_caducidad
CREATE INDEX IF NOT EXISTS ix_inventario_stock_fecha_caducidad
ON inventario_stock (fecha_caducidad);

-- 4) inventario_stock: composite index (user_id, fecha_caducidad)
CREATE INDEX IF NOT EXISTS ix_stock_user_fecha
ON inventario_stock (user_id, fecha_caducidad);
