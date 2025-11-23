-- Script de ROLLBACK en caso de que necesites revertir cambios parciales
-- SOLO ejecuta esto si la migración falló a medias

-- Eliminar columnas (si existen)
ALTER TABLE inventario_stock DROP COLUMN IF EXISTS estado_producto;
ALTER TABLE inventario_stock DROP COLUMN IF EXISTS fecha_apertura;
ALTER TABLE inventario_stock DROP COLUMN IF EXISTS fecha_congelacion;
ALTER TABLE inventario_stock DROP COLUMN IF EXISTS dias_caducidad_abierto;

-- Eliminar índice (si existe)
DROP INDEX IF EXISTS ix_inventario_stock_estado;

-- Eliminar constraint (si existe)
-- Nota: Los constraints creados con DO blocks tienen nombres automáticos
-- Puedes verificar el nombre real con el script CHECK_CURRENT_STATE.sql
-- y luego ejecutar: ALTER TABLE inventario_stock DROP CONSTRAINT nombre_del_constraint;

-- Verificar que se eliminaron
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'inventario_stock'
ORDER BY ordinal_position;
