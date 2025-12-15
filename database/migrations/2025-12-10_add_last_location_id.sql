-- Add last_location_id to producto_maestro for Smart Grouping (Product Memory)
ALTER TABLE producto_maestro ADD COLUMN last_location_id INTEGER REFERENCES ubicacion(id_ubicacion) ON DELETE SET NULL;
