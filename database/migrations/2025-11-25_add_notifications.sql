-- database/migrations/2025-11-25_add_notifications.sql

-- Tabla para guardar los tokens FCM de los dispositivos de los usuarios
-- Un usuario puede tener múltiples dispositivos (móvil, tablet, web)
CREATE TABLE IF NOT EXISTS user_devices (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    fcm_token TEXT NOT NULL,
    platform VARCHAR(50), -- 'android', 'web', 'ios'
    last_active TIMESTAMP DEFAULT NOW(),
    -- Evitamos duplicados: un mismo token para un mismo usuario solo una vez
    UNIQUE(user_id, fcm_token)
);

-- Tabla para guardar las preferencias de notificación de los usuarios
-- Configuración global por usuario (no por dispositivo)
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id VARCHAR(255) PRIMARY KEY,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    notification_time TIME DEFAULT '09:00:00', -- Hora local deseada
    timezone_offset INTEGER DEFAULT 0 -- Offset en minutos (ej: -60 para UTC+1) para calcular la hora UTC correcta en el backend
);
