-- Migration: Fix Constraints en Producción
-- Date: 2025-11-24
-- Description: Corrige constraints que pueden estar causando conflictos 409

-- ============================================================================
-- DIAGNÓSTICO: Ver constraints actuales
-- ============================================================================
-- Ejecuta esto primero para ver qué constraints existen:
/*
SELECT 
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'ubicacion'::regclass
ORDER BY conname;

SELECT 
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'producto_maestro'::regclass
ORDER BY conname;
*/

-- ============================================================================
-- LIMPIEZA DE CONSTRAINTS ANTIGUOS
-- ============================================================================
-- Este script elimina los constraints basados en user_id que causan conflictos 409
-- y deja solo los constraints correctos basados en hogar_id

-- Tabla ubicacion: eliminar constraint antiguo
ALTER TABLE ubicacion DROP CONSTRAINT IF EXISTS ubicacion_nombre_user_id_key;

-- Tabla producto_maestro: eliminar constraints antiguos
ALTER TABLE producto_maestro DROP CONSTRAINT IF EXISTS unique_barcode_user;
ALTER TABLE producto_maestro DROP CONSTRAINT IF EXISTS producto_maestro_barcode_user_id_key;

-- ============================================================================
-- VERIFICACIÓN: Confirmar que quedaron solo los constraints correctos
-- ============================================================================

-- Verificar ubicacion - Debe mostrar solo: ubicacion_nombre_hogar_unique
SELECT 'ubicacion' as tabla, conname, pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conrelid = 'ubicacion'::regclass AND contype = 'u'
ORDER BY conname;

-- Verificar producto_maestro - Debe mostrar solo: producto_barcode_hogar_unique
SELECT 'producto_maestro' as tabla, conname, pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conrelid = 'producto_maestro'::regclass AND contype = 'u'
ORDER BY conname;

-- ============================================================================
-- RESULTADO ESPERADO:
-- ============================================================================
-- tabla            | conname                       | definition
-- -----------------+-------------------------------+----------------------------
-- ubicacion        | ubicacion_nombre_hogar_unique | UNIQUE (nombre, hogar_id)
-- producto_maestro | producto_barcode_hogar_unique | UNIQUE (barcode, hogar_id)
