-- Script para verificar el estado actual de la tabla inventario_stock
-- Ejecuta esto primero para ver qué columnas ya existen

-- Ver todas las columnas de la tabla
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'inventario_stock'
ORDER BY ordinal_position;

-- Ver los constraints existentes
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'inventario_stock';

-- Ver los índices existentes
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'inventario_stock';
