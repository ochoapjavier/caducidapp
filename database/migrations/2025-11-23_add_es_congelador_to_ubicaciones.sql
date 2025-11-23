-- Migration: Add es_congelador field to ubicaciones table
-- Date: 2025-11-23
-- Description: Adds a boolean field to mark locations as freezer type

DO $$ 
BEGIN
    -- Add es_congelador column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'ubicacion' 
        AND column_name = 'es_congelador'
    ) THEN
        ALTER TABLE ubicacion 
        ADD COLUMN es_congelador BOOLEAN NOT NULL DEFAULT FALSE;
        
        RAISE NOTICE 'Column es_congelador added to ubicacion table';
    ELSE
        RAISE NOTICE 'Column es_congelador already exists in ubicacion table';
    END IF;
END $$;

-- Optional: Update existing freezer locations
-- Uncomment and modify the names according to your existing freezer locations
-- UPDATE ubicacion SET es_congelador = TRUE WHERE LOWER(nombre) LIKE '%congelador%';
-- UPDATE ubicacion SET es_congelador = TRUE WHERE LOWER(nombre) LIKE '%freezer%';

COMMENT ON COLUMN ubicacion.es_congelador IS 'Indicates if this location is a freezer type (true) or not (false)';
