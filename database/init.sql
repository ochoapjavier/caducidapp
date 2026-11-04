-- database/init.sql
-- Complete and updated PostgreSQL schema for Caducidapp (multi-household, products, stock, OCR, shopping list)

-- 1. Hogares
CREATE TABLE IF NOT EXISTS hogares (
    id_hogar SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    fecha_creacion TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    icono VARCHAR(50) DEFAULT 'home' NOT NULL,
    codigo_invitacion VARCHAR(8) UNIQUE NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_hogares_created_by ON hogares(created_by);
CREATE INDEX IF NOT EXISTS ix_hogares_codigo_invitacion ON hogares(codigo_invitacion);

-- 2. Miembros de Hogar
CREATE TABLE IF NOT EXISTS hogares_miembros (
    id_miembro SERIAL PRIMARY KEY,
    fk_hogar INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL,
    rol VARCHAR(50) DEFAULT 'miembro' NOT NULL,
    fecha_union TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    apodo VARCHAR(100),
    CONSTRAINT hogar_miembro_unique UNIQUE (fk_hogar, user_id)
);
CREATE INDEX IF NOT EXISTS ix_hogares_miembros_fk_hogar ON hogares_miembros(fk_hogar);
CREATE INDEX IF NOT EXISTS ix_hogares_miembros_user_id ON hogares_miembros(user_id);
CREATE INDEX IF NOT EXISTS ix_hogares_miembros_rol ON hogares_miembros(rol);

-- 3. Ubicaciones (Nevera, Despensa, etc.)
CREATE TABLE IF NOT EXISTS ubicacion (
    id_ubicacion SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    hogar_id INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    es_congelador BOOLEAN DEFAULT FALSE NOT NULL,
    CONSTRAINT ubicacion_nombre_hogar_unique UNIQUE (nombre, hogar_id)
);
CREATE INDEX IF NOT EXISTS ix_ubicacion_hogar_id ON ubicacion(hogar_id);

-- 4. Catálogo de Productos Maestros
CREATE TABLE IF NOT EXISTS producto_maestro (
    id_producto SERIAL PRIMARY KEY,
    barcode VARCHAR(20),
    nombre VARCHAR(255) NOT NULL,
    marca VARCHAR(100),
    image_url VARCHAR(512),
    dias_consumo_abierto INTEGER,
    hogar_id INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    nova_group INTEGER,
    nutriscore_grade VARCHAR(2),
    alergenos TEXT,
    aditivos_count INTEGER DEFAULT 0,
    semaforo_nutricional TEXT,
    nutrientes_100g TEXT,
    nutricion_sync_at TIMESTAMP WITHOUT TIME ZONE,
    CONSTRAINT producto_barcode_hogar_unique UNIQUE (barcode, hogar_id)
);
CREATE INDEX IF NOT EXISTS ix_producto_maestro_barcode ON producto_maestro(barcode);
CREATE INDEX IF NOT EXISTS ix_producto_maestro_nombre ON producto_maestro(nombre);
CREATE INDEX IF NOT EXISTS ix_producto_maestro_hogar_id ON producto_maestro(hogar_id);
CREATE INDEX IF NOT EXISTS ix_producto_hogar_nombre ON producto_maestro(hogar_id, nombre);

-- 5. Inventario de Stock
CREATE TABLE IF NOT EXISTS inventario_stock (
    id_stock SERIAL PRIMARY KEY,
    hogar_id INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    fk_producto_maestro INTEGER NOT NULL REFERENCES producto_maestro(id_producto) ON DELETE CASCADE,
    fk_ubicacion INTEGER NOT NULL REFERENCES ubicacion(id_ubicacion) ON DELETE CASCADE,
    cantidad_actual INTEGER NOT NULL CHECK (cantidad_actual >= 0),
    fecha_caducidad DATE NOT NULL,
    estado VARCHAR(50) DEFAULT 'Activo',
    estado_producto VARCHAR(20) DEFAULT 'cerrado' NOT NULL,
    fecha_apertura DATE,
    fecha_congelacion DATE,
    fecha_descongelacion DATE,
    dias_caducidad_abierto INTEGER
);
CREATE INDEX IF NOT EXISTS ix_inventario_stock_hogar_id ON inventario_stock(hogar_id);
CREATE INDEX IF NOT EXISTS ix_inventario_stock_fecha_caducidad ON inventario_stock(fecha_caducidad);
CREATE INDEX IF NOT EXISTS ix_stock_hogar_fecha ON inventario_stock(hogar_id, fecha_caducidad);
CREATE INDEX IF NOT EXISTS ix_inventario_stock_estado ON inventario_stock(estado_producto);

-- 6. Dispositivos FCM
CREATE TABLE IF NOT EXISTS user_devices (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    fcm_token TEXT NOT NULL,
    platform VARCHAR(50),
    last_active TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT user_device_unique UNIQUE (user_id, fcm_token)
);
CREATE INDEX IF NOT EXISTS ix_user_devices_user_id ON user_devices(user_id);

-- 7. Preferencias de Notificación
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id VARCHAR(255) PRIMARY KEY,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    notification_time VARCHAR(8) DEFAULT '09:00:00',
    timezone_offset INTEGER DEFAULT 0
);

-- 8. Lista de la Compra
CREATE TABLE IF NOT EXISTS shopping_list_items (
    id SERIAL PRIMARY KEY,
    hogar_id INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    producto_nombre VARCHAR(255) NOT NULL,
    fk_producto INTEGER REFERENCES producto_maestro(id_producto) ON DELETE SET NULL,
    cantidad INTEGER DEFAULT 1 NOT NULL,
    completado BOOLEAN DEFAULT FALSE NOT NULL,
    added_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_shopping_list_items_hogar_id ON shopping_list_items(hogar_id);
CREATE INDEX IF NOT EXISTS ix_shopping_list_items_completado ON shopping_list_items(completado);

-- 9. Supermercados
CREATE TABLE IF NOT EXISTS supermercados (
    id_supermercado SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    logo_url VARCHAR(512),
    color_hex VARCHAR(7)
);
CREATE INDEX IF NOT EXISTS ix_supermercados_nombre ON supermercados(nombre);

-- 10. Diccionario Ticket OCR -> Producto Maestro
CREATE TABLE IF NOT EXISTS diccionario_ticket_producto (
    id_diccionario SERIAL PRIMARY KEY,
    hogar_id INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    ticket_nombre VARCHAR(255) NOT NULL,
    fk_supermercado INTEGER NOT NULL REFERENCES supermercados(id_supermercado) ON DELETE CASCADE,
    fk_producto_maestro INTEGER NOT NULL REFERENCES producto_maestro(id_producto) ON DELETE CASCADE,
    CONSTRAINT ticket_super_producto_unique UNIQUE (hogar_id, fk_supermercado, ticket_nombre, fk_producto_maestro)
);
CREATE INDEX IF NOT EXISTS ix_diccionario_ticket_hogar_id ON diccionario_ticket_producto(hogar_id);
CREATE INDEX IF NOT EXISTS ix_diccionario_ticket_nombre ON diccionario_ticket_producto(ticket_nombre);
CREATE INDEX IF NOT EXISTS ix_diccionario_ticket_supermercado ON diccionario_ticket_producto(fk_supermercado);

-- 11. Valoraciones de Productos
CREATE TABLE IF NOT EXISTS producto_valoracion (
    id_valoracion SERIAL PRIMARY KEY,
    fk_producto INTEGER NOT NULL REFERENCES producto_maestro(id_producto) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL,
    hogar_id INTEGER NOT NULL REFERENCES hogares(id_hogar) ON DELETE CASCADE,
    puntuacion FLOAT NOT NULL,
    es_favorito BOOLEAN DEFAULT FALSE NOT NULL,
    nota TEXT,
    tags VARCHAR(255),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT producto_valoracion_user_unique UNIQUE (fk_producto, user_id)
);
CREATE INDEX IF NOT EXISTS ix_producto_valoracion_fk_producto ON producto_valoracion(fk_producto);
CREATE INDEX IF NOT EXISTS ix_producto_valoracion_user_id ON producto_valoracion(user_id);
CREATE INDEX IF NOT EXISTS ix_producto_valoracion_hogar_id ON producto_valoracion(hogar_id);
CREATE INDEX IF NOT EXISTS ix_producto_valoracion_favorito ON producto_valoracion(hogar_id, user_id, es_favorito);
