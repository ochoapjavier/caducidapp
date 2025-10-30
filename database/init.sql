-- database/init.sql

-- Tabla 1: Ubicaciones (Ej. Nevera, Despensa)
CREATE TABLE ubicacion (
    id_ubicacion SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    user_id VARCHAR(255) NOT NULL, -- ID de usuario de Firebase
    UNIQUE(nombre, user_id) -- El nombre de la ubicación debe ser único POR USUARIO
);

-- Tabla 2: Productos Maestros (Para evitar redundancia de nombres)
CREATE TABLE producto_maestro (
    id_producto SERIAL PRIMARY KEY,
    barcode VARCHAR(20) UNIQUE, -- El código de barras (EAN/UPC). Único pero puede ser NULL.
    nombre VARCHAR(255) NOT NULL,
    marca VARCHAR(100) -- La marca del producto, puede ser NULL.
);

-- Índice para búsquedas eficientes de nombres en productos sin código de barras
CREATE INDEX idx_producto_maestro_nombre_sin_barcode ON producto_maestro (LOWER(nombre)) WHERE barcode IS NULL;

-- Tabla 3: Inventario Activo (El centro de la aplicación)
CREATE TABLE inventario_stock (
    id_stock SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL, -- ID de usuario de Firebase
    -- Referencia al producto
    fk_producto_maestro INTEGER REFERENCES producto_maestro(id_producto) NOT NULL,
    -- Referencia a la ubicación física
    fk_ubicacion INTEGER REFERENCES ubicacion(id_ubicacion) NOT NULL,
    cantidad_actual INTEGER NOT NULL CHECK (cantidad_actual >= 0),
    fecha_caducidad DATE NOT NULL,
    estado VARCHAR(50) DEFAULT 'Activo'
);