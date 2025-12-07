-- database/migrations/2025-12-06_add_dias_consumo_abierto.sql

-- Añadir columna para guardar la preferencia de días de consumo una vez abierto
ALTER TABLE producto_maestro ADD COLUMN IF NOT EXISTS dias_consumo_abierto INTEGER NULL;
