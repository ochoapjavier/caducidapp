-- Migration: Add fecha_descongelacion field to inventario_stock table
-- Date: 2025-11-24
-- Description: Adds fecha_descongelacion field to track when frozen products are unfrozen
--              This allows differentiating 'descongelado' state from 'abierto' state
--              Also updates the CHECK constraint to allow 'descongelado' as a valid state

DO $$ 
BEGIN
    -- Add fecha_descongelacion column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'inventario_stock' 
        AND column_name = 'fecha_descongelacion'
    ) THEN
        ALTER TABLE inventario_stock 
        ADD COLUMN fecha_descongelacion DATE NULL;
        
        RAISE NOTICE 'Column fecha_descongelacion added to inventario_stock table';
    ELSE
        RAISE NOTICE 'Column fecha_descongelacion already exists in inventario_stock table';
    END IF;
    
    -- Drop old CHECK constraint if it exists
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'chk_estado_producto' 
        AND table_name = 'inventario_stock'
    ) THEN
        ALTER TABLE inventario_stock DROP CONSTRAINT chk_estado_producto;
        RAISE NOTICE 'Old CHECK constraint chk_estado_producto dropped';
    END IF;
    
    -- Add new CHECK constraint with 'descongelado' included
    ALTER TABLE inventario_stock 
    ADD CONSTRAINT chk_estado_producto 
    CHECK (estado_producto IN ('cerrado', 'abierto', 'congelado', 'descongelado'));
    
    RAISE NOTICE 'New CHECK constraint chk_estado_producto created with descongelado state';
END $$;

COMMENT ON COLUMN inventario_stock.fecha_descongelacion IS 'Date when a frozen product was unfrozen (thawed). Used to track unfrozen products that need quick consumption.';
