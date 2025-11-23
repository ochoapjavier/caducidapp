-- Caducidapp DB Migration: add product states (open, frozen, closed)
-- Date: 2025-11-22
-- Description: Añade campos para manejar estados de productos (abierto, congelado, cerrado)
--              y cambios de ubicación
-- Este script es IDEMPOTENTE: puede ejecutarse múltiples veces sin error

-- 1) Agregar columna para el estado del producto
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'inventario_stock' 
        AND column_name = 'estado_producto'
    ) THEN
        ALTER TABLE inventario_stock 
        ADD COLUMN estado_producto VARCHAR(20) DEFAULT 'cerrado' NOT NULL;
        
        COMMENT ON COLUMN inventario_stock.estado_producto IS 
        'Estado del producto: cerrado (sin abrir), abierto, congelado';
    END IF;
END $$;

-- 2) Agregar columna para fecha de apertura
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'inventario_stock' 
        AND column_name = 'fecha_apertura'
    ) THEN
        ALTER TABLE inventario_stock 
        ADD COLUMN fecha_apertura DATE NULL;
        
        COMMENT ON COLUMN inventario_stock.fecha_apertura IS 
        'Fecha en que se abrió el producto (para recalcular caducidad)';
    END IF;
END $$;

-- 3) Agregar columna para fecha de congelación
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'inventario_stock' 
        AND column_name = 'fecha_congelacion'
    ) THEN
        ALTER TABLE inventario_stock 
        ADD COLUMN fecha_congelacion DATE NULL;
        
        COMMENT ON COLUMN inventario_stock.fecha_congelacion IS 
        'Fecha en que se congeló el producto (pausa la caducidad)';
    END IF;
END $$;

-- 4) Agregar columna para días de vida útil una vez abierto
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'inventario_stock' 
        AND column_name = 'dias_caducidad_abierto'
    ) THEN
        ALTER TABLE inventario_stock 
        ADD COLUMN dias_caducidad_abierto INTEGER NULL;
        
        COMMENT ON COLUMN inventario_stock.dias_caducidad_abierto IS 
        'Días de vida útil del producto una vez abierto (ej: leche = 3-4 días)';
    END IF;
END $$;

-- 5) Agregar índice para búsquedas por estado
CREATE INDEX IF NOT EXISTS ix_inventario_stock_estado 
ON inventario_stock (estado_producto);

-- 6) Agregar constraint para validar estados permitidos
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage 
        WHERE table_name = 'inventario_stock' 
        AND constraint_name = 'chk_estado_producto'
    ) THEN
        ALTER TABLE inventario_stock 
        ADD CONSTRAINT chk_estado_producto 
        CHECK (estado_producto IN ('cerrado', 'abierto', 'congelado'));
    END IF;
END $$;

-- Información de la migración
DO $$
BEGIN
    RAISE NOTICE 'Migración completada: Estados de productos añadidos correctamente';
    RAISE NOTICE 'Estados permitidos: cerrado, abierto, congelado';
END $$;
