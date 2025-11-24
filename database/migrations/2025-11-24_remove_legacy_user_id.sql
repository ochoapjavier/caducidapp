-- Migration: Remove Legacy user_id Columns
-- Date: 2025-11-24
-- Description: Elimina completamente las columnas user_id legacy de las tablas
--              que ahora usan hogar_id para aislamiento multi-tenant

-- ============================================================================
-- PASO 1: ELIMINAR ÍNDICES asociados a user_id
-- ============================================================================

-- Ubicacion
DROP INDEX IF EXISTS ix_ubicacion_user_id;

-- Producto Maestro
DROP INDEX IF EXISTS ix_producto_maestro_user_id;

-- Inventario Stock
DROP INDEX IF EXISTS ix_inventario_stock_user_id;

-- ============================================================================
-- PASO 2: ELIMINAR COLUMNAS user_id
-- ============================================================================

-- Ubicacion
ALTER TABLE ubicacion DROP COLUMN IF EXISTS user_id;

-- Producto Maestro
ALTER TABLE producto_maestro DROP COLUMN IF EXISTS user_id;

-- Inventario Stock
ALTER TABLE inventario_stock DROP COLUMN IF EXISTS user_id;

-- ============================================================================
-- VERIFICACIÓN: Confirmar que las columnas fueron eliminadas
-- ============================================================================

-- Ver columnas restantes en ubicacion
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'ubicacion'
ORDER BY ordinal_position;

-- Ver columnas restantes en producto_maestro
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'producto_maestro'
ORDER BY ordinal_position;

-- Ver columnas restantes en inventario_stock
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'inventario_stock'
ORDER BY ordinal_position;

-- ============================================================================
-- RESULTADO ESPERADO:
-- ============================================================================
-- Las tablas NO deben tener columna "user_id"
-- Solo hogares_miembros debe mantener user_id (tabla de relación usuario-hogar)
