-- Notification reliability: stable installations, IANA timezones and idempotent deliveries.

ALTER TABLE user_devices
    ADD COLUMN IF NOT EXISTS installation_id VARCHAR(128),
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITHOUT TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS last_error_code VARCHAR(100),
    ADD COLUMN IF NOT EXISTS last_error_at TIMESTAMP WITHOUT TIME ZONE;

CREATE INDEX IF NOT EXISTS ix_user_devices_installation_id
    ON user_devices(installation_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_user_devices_user_installation
    ON user_devices(user_id, installation_id)
    WHERE installation_id IS NOT NULL;

ALTER TABLE user_preferences
    ADD COLUMN IF NOT EXISTS timezone VARCHAR(64);

UPDATE user_preferences
SET timezone = 'Europe/Madrid'
WHERE timezone IS NULL OR timezone = '';

ALTER TABLE user_preferences
    ALTER COLUMN timezone SET DEFAULT 'Europe/Madrid',
    ALTER COLUMN timezone SET NOT NULL;

CREATE TABLE IF NOT EXISTS notification_deliveries (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    notification_type VARCHAR(80) NOT NULL,
    reference_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    attempted_at TIMESTAMP WITHOUT TIME ZONE,
    sent_at TIMESTAMP WITHOUT TIME ZONE,
    provider_message_id VARCHAR(255),
    error_code VARCHAR(100),
    error_message TEXT,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT notification_delivery_status_check
        CHECK (status IN ('pending', 'sent', 'failed')),
    CONSTRAINT notification_delivery_unique
        UNIQUE (user_id, notification_type, reference_date)
);

CREATE INDEX IF NOT EXISTS ix_notification_deliveries_user
    ON notification_deliveries(user_id);
CREATE INDEX IF NOT EXISTS ix_notification_deliveries_status
    ON notification_deliveries(status);
CREATE INDEX IF NOT EXISTS ix_notification_deliveries_reference_date
    ON notification_deliveries(reference_date);
