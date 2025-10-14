-- database/init.sql

-- Tabla 1: Ubicaciones (Ej. Nevera, Despensa)
CREATE TABLE Ubicacion (
    id_ubicacion SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL
);

-- Tabla 2: Productos Maestros (Para evitar redundancia de nombres)
CREATE TABLE ProductoMaestro (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(255) UNIQUE NOT NULL
);

-- Tabla 3: Inventario Activo (El centro de la aplicación)
CREATE TABLE InventarioStock (
    id_stock SERIAL PRIMARY KEY,
    -- Referencia al producto
    fk_producto_maestro INTEGER REFERENCES ProductoMaestro(id_producto) NOT NULL,
    -- Referencia a la ubicación física
    fk_ubicacion INTEGER REFERENCES Ubicacion(id_ubicacion) NOT NULL,
    cantidad_actual INTEGER NOT NULL CHECK (cantidad_actual >= 0),
    fecha_caducidad DATE NOT NULL,
    estado VARCHAR(50) DEFAULT 'Activo'
);

-- Datos iniciales (Seed Data)
INSERT INTO Ubicacion (nombre) VALUES ('Nevera'), ('Despensa'), ('Congelador');

-- Inserción de prueba para verificar las alertas
INSERT INTO ProductoMaestro (nombre) VALUES ('Leche Entera'), ('Yogur de Fresa');

INSERT INTO InventarioStock (fk_producto_maestro, fk_ubicacion, cantidad_actual, fecha_caducidad)
VALUES
(1, 1, 1, '2025-10-14'), -- Caduca mañana (en rango de 7 días)
(2, 1, 6, '2025-11-20'); -- Caduca mucho más tarde