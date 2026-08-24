-- database/migrations/2026-08-24_add_product_nutrition.sql
-- Migración para añadir campos de Nutrición, NOVA (MyRealFood), Nutri-Score y Tabla por 100g a producto_maestro

ALTER TABLE producto_maestro
ADD COLUMN IF NOT EXISTS nova_group INTEGER,                             -- 1: Comida Real, 2/3: Buen Procesado, 4: Ultraprocesado
ADD COLUMN IF NOT EXISTS nutriscore_grade VARCHAR(2),                    -- 'a', 'b', 'c', 'd', 'e'
ADD COLUMN IF NOT EXISTS alergenos TEXT,                                 -- JSON string list ["nuts", "milk"]
ADD COLUMN IF NOT EXISTS aditivos_count INTEGER DEFAULT 0,               -- Conteo total de aditivos E-xxx
ADD COLUMN IF NOT EXISTS semaforo_nutricional TEXT,                      -- JSON dict {"fat": "low", "saturated_fat": "low", "sugars": "high", "salt": "low"}
ADD COLUMN IF NOT EXISTS nutrientes_100g TEXT,                           -- JSON dict {"energy_kcal": 49, "carbohydrates": 13, "sugars": 4.6, "fat": 0, "saturated_fat": 0, "proteins": 0, "salt": 0.04}
ADD COLUMN IF NOT EXISTS nutricion_sync_at TIMESTAMP DEFAULT NOW();       -- Fecha de última actualización de datos nutricionales
