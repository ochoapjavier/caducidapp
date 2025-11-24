-- Migration: Sistema Multihogar
-- Date: 2025-11-23
-- Description: Añade tablas para hogares y migra datos de user_id a hogar_id

-- ============================================================================
-- PASO 1: Crear tabla de hogares
-- ============================================================================

CREATE TABLE hogares (
    id_hogar SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    created_by VARCHAR(255) NOT NULL, -- user_id del creador (Firebase UID)
    fecha_creacion TIMESTAMP DEFAULT NOW(),
    icono VARCHAR(50) DEFAULT 'home', -- 'home', 'apartment', 'cabin', 'office', etc.
    codigo_invitacion VARCHAR(8) UNIQUE NOT NULL -- Código para invitar miembros
);

CREATE INDEX idx_hogares_created_by ON hogares(created_by);
CREATE INDEX idx_hogares_codigo ON hogares(codigo_invitacion);

-- ============================================================================
-- PASO 2: Crear tabla de membresías (usuarios en hogares)
-- ============================================================================

CREATE TABLE hogares_miembros (
    id_miembro SERIAL PRIMARY KEY,
    fk_hogar INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL, -- Firebase UID
    rol VARCHAR(50) NOT NULL DEFAULT 'miembro', -- 'admin', 'miembro', 'invitado'
    fecha_union TIMESTAMP DEFAULT NOW(),
    apodo VARCHAR(100), -- Nombre amigable: "Mamá", "Javi", etc.
    UNIQUE(fk_hogar, user_id) -- Un usuario solo puede estar una vez por hogar
);

CREATE INDEX idx_hogares_miembros_user ON hogares_miembros(user_id);
CREATE INDEX idx_hogares_miembros_hogar ON hogares_miembros(fk_hogar);
CREATE INDEX idx_hogares_miembros_rol ON hogares_miembros(rol);

-- ============================================================================
-- PASO 3: Añadir columna hogar_id a las tablas existentes
-- ============================================================================

-- Ubicaciones
ALTER TABLE ubicacion ADD COLUMN hogar_id INTEGER;
ALTER TABLE ubicacion ADD CONSTRAINT fk_ubicacion_hogar 
    FOREIGN KEY (hogar_id) REFERENCES hogares(id_hogar) ON DELETE CASCADE;
CREATE INDEX idx_ubicacion_hogar ON ubicacion(hogar_id);

-- Productos maestros
ALTER TABLE producto_maestro ADD COLUMN hogar_id INTEGER;
ALTER TABLE producto_maestro ADD CONSTRAINT fk_producto_maestro_hogar 
    FOREIGN KEY (hogar_id) REFERENCES hogares(id_hogar) ON DELETE CASCADE;
CREATE INDEX idx_producto_maestro_hogar ON producto_maestro(hogar_id);

-- Inventario stock
ALTER TABLE inventario_stock ADD COLUMN hogar_id INTEGER;
ALTER TABLE inventario_stock ADD CONSTRAINT fk_inventario_stock_hogar 
    FOREIGN KEY (hogar_id) REFERENCES hogares(id_hogar) ON DELETE CASCADE;
CREATE INDEX idx_inventario_stock_hogar ON inventario_stock(hogar_id);

-- ============================================================================
-- PASO 4: Migración de datos existentes
-- ============================================================================

-- Crear un hogar automático para cada usuario existente
INSERT INTO hogares (nombre, created_by, codigo_invitacion)
SELECT 
    'Mi Hogar' AS nombre,
    user_id,
    UPPER(SUBSTRING(MD5(RANDOM()::TEXT || user_id), 1, 8)) AS codigo_invitacion
FROM (
    SELECT DISTINCT user_id FROM ubicacion
    UNION
    SELECT DISTINCT user_id FROM producto_maestro
    UNION
    SELECT DISTINCT user_id FROM inventario_stock
) AS usuarios_existentes;

-- Crear membresía automática (cada usuario es admin de su hogar)
INSERT INTO hogares_miembros (fk_hogar, user_id, rol, apodo)
SELECT 
    h.id_hogar,
    h.created_by,
    'admin' AS rol,
    'Yo' AS apodo
FROM hogares h;

-- Migrar ubicaciones: asignar hogar_id basado en user_id
UPDATE ubicacion u
SET hogar_id = (
    SELECT h.id_hogar 
    FROM hogares h 
    WHERE h.created_by = u.user_id
    LIMIT 1
);

-- Migrar productos: asignar hogar_id basado en user_id
UPDATE producto_maestro p
SET hogar_id = (
    SELECT h.id_hogar 
    FROM hogares h 
    WHERE h.created_by = p.user_id
    LIMIT 1
);

-- Migrar inventario: asignar hogar_id basado en user_id
UPDATE inventario_stock s
SET hogar_id = (
    SELECT h.id_hogar 
    FROM hogares h 
    WHERE h.created_by = s.user_id
    LIMIT 1
);

-- ============================================================================
-- PASO 5: Hacer hogar_id obligatorio y actualizar constraints
-- ============================================================================

-- Ahora que todos los registros tienen hogar_id, lo hacemos NOT NULL
ALTER TABLE ubicacion ALTER COLUMN hogar_id SET NOT NULL;
ALTER TABLE producto_maestro ALTER COLUMN hogar_id SET NOT NULL;
ALTER TABLE inventario_stock ALTER COLUMN hogar_id SET NOT NULL;

-- Actualizar constraint de unicidad en ubicaciones (nombre único por hogar)
ALTER TABLE ubicacion DROP CONSTRAINT IF EXISTS _nombre_user_uc;
ALTER TABLE ubicacion ADD CONSTRAINT ubicacion_nombre_hogar_unique 
    UNIQUE(nombre, hogar_id);

-- Actualizar constraint de unicidad en productos (barcode único por hogar)
ALTER TABLE producto_maestro DROP CONSTRAINT IF EXISTS _barcode_user_uc;
ALTER TABLE producto_maestro ADD CONSTRAINT producto_barcode_hogar_unique 
    UNIQUE(barcode, hogar_id);

-- ============================================================================
-- PASO 6: (OPCIONAL) Eliminar columnas user_id antiguas
-- ============================================================================
-- IMPORTANTE: Descomenta estas líneas SOLO cuando estés seguro de que 
-- el backend ya no usa user_id y todo funciona con hogar_id

-- ALTER TABLE ubicacion DROP COLUMN user_id;
-- ALTER TABLE producto_maestro DROP COLUMN user_id;
-- ALTER TABLE inventario_stock DROP COLUMN user_id;

-- ============================================================================
-- VERIFICACIÓN: Consultas útiles para verificar la migración
-- ============================================================================

-- Contar hogares creados
-- SELECT COUNT(*) as total_hogares FROM hogares;

-- Contar miembros por hogar
-- SELECT h.nombre, COUNT(m.id_miembro) as total_miembros
-- FROM hogares h
-- LEFT JOIN hogares_miembros m ON h.id_hogar = m.fk_hogar
-- GROUP BY h.id_hogar, h.nombre;

-- Verificar que todos los registros tienen hogar_id
-- SELECT 
--     (SELECT COUNT(*) FROM ubicacion WHERE hogar_id IS NULL) as ubicaciones_sin_hogar,
--     (SELECT COUNT(*) FROM producto_maestro WHERE hogar_id IS NULL) as productos_sin_hogar,
--     (SELECT COUNT(*) FROM inventario_stock WHERE hogar_id IS NULL) as stock_sin_hogar;
