-- Script de Migración para Supabase (Smart Receipts)
-- Ejecuta este código en el editor SQL de tu panel de Supabase en Producción

-- 1. Crear tabla GLOBAL de Supermercados (Sin hogar_id) si no existe
CREATE TABLE IF NOT EXISTS supermercados (
    id_supermercado SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    logo_url VARCHAR(512),
    color_hex VARCHAR(7)
);

-- 2. Insertar los principales supermercados semilla
INSERT INTO supermercados (nombre, logo_url, color_hex) VALUES 
('Mercadona', 'https://cdn.brandfetch.io/ideNsmUt1m/w/331/h/47/theme/dark/logo.png?c=1bxid64Mup7aczewSAYMX&t=1771954454417', '#009A63'),
('Lidl', 'https://cdn.brandfetch.io/idw-qC2UFC/theme/dark/logo.svg?c=1bxid64Mup7aczewSAYMX&t=1755376654291', '#FFF000'),
('Dia', 'https://cdn.brandfetch.io/idrcO3pEzj/w/103/h/103/theme/dark/logo.png?c=1bxid64Mup7aczewSAYMX&t=1765243714689', '#FF0000'),
('Carrefour', 'https://cdn.brandfetch.io/id-u6HlO7m/theme/dark/logo.svg?c=1bxid64Mup7aczewSAYMX&t=1668162012478', '#005CA9'),
('Aldi', 'https://cdn.brandfetch.io/idoanWWg6q/theme/dark/logo.svg?c=1bxid64Mup7aczewSAYMX&t=1667578903622', '#2490D7'),
('Consum', 'https://cdn.brandfetch.io/id8JPC4xkR/w/400/h/400/theme/dark/icon.png?c=1bxid64Mup7aczewSAYMX&t=1772630584843', '#F39400'),
('Covirán', 'https://cdn.brandfetch.io/idE9wmZwpZ/w/205/h/46/theme/dark/logo.png?c=1bxid64Mup7aczewSAYMX&t=1772702788685', '#01973E'),
('Eroski', 'https://cdn.brandfetch.io/idDAeeq8LP/theme/dark/logo.svg?c=1bxid64Mup7aczewSAYMX&t=1765278120399', '#D31E17'),
('Alcampo', 'https://cdn.brandfetch.io/id1bUJVxjB/theme/dark/logo.svg?c=1bxid64Mup7aczewSAYMX&t=1719241108122', '#E60410'),
('Ahorramas', 'https://cdn.brandfetch.io/idCV7nurb4/w/150/h/30/theme/dark/logo.png?c=1bxid64Mup7aczewSAYMX&t=1669112740557', '#CB3A35'),
('Desconocido', NULL, '#808080')
ON CONFLICT (nombre) DO UPDATE SET 
    logo_url = EXCLUDED.logo_url, 
    color_hex = EXCLUDED.color_hex;

-- 3. Crear la tabla de memoria del diccionario (apuntando al nuevo id_supermercado) si no existe
CREATE TABLE IF NOT EXISTS diccionario_ticket_producto (
    id_diccionario SERIAL PRIMARY KEY,
    hogar_id INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    ticket_nombre VARCHAR(255) NOT NULL,
    fk_supermercado INTEGER NOT NULL REFERENCES supermercados(id_supermercado) ON DELETE CASCADE,
    fk_producto_maestro INTEGER NOT NULL REFERENCES producto_maestro(id_producto) ON DELETE CASCADE
);

-- 4. Crear los índices para optimizar las búsquedas 
CREATE INDEX IF NOT EXISTS idx_diccionario_ticket_nombre ON diccionario_ticket_producto(ticket_nombre);
CREATE INDEX IF NOT EXISTS idx_diccionario_hogar_id ON diccionario_ticket_producto(hogar_id);
CREATE INDEX IF NOT EXISTS idx_diccionario_fk_supermercado ON diccionario_ticket_producto(fk_supermercado);

-- 5. Sustitución de regla estricta: Ahora un ticket puede coincidir con N productos distintos (Vainilla, Chocolate)
ALTER TABLE IF EXISTS diccionario_ticket_producto DROP CONSTRAINT IF EXISTS ticket_supermercado_hogar_unique;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ticket_super_producto_unique'
    ) THEN
        ALTER TABLE diccionario_ticket_producto 
        ADD CONSTRAINT ticket_super_producto_unique UNIQUE (hogar_id, fk_supermercado, ticket_nombre, fk_producto_maestro);
    END IF;
END $$;

-- 6. Activar Row Level Security (RLS)
ALTER TABLE supermercados ENABLE ROW LEVEL SECURITY;
ALTER TABLE diccionario_ticket_producto ENABLE ROW LEVEL SECURITY;

-- Confirmación visual
SELECT 'Tablas Supermercados y DiccionarioTicketProducto creadas con éxito' as status;
