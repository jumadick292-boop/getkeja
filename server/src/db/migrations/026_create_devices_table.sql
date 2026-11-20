-- Migration: 028_create_devices_table
-- Description: Create devices table for device management and push notifications

CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_identifier VARCHAR(255) NOT NULL,
    platform VARCHAR(20) NOT NULL, -- 'web', 'android', 'ios', 'other'
    device_name VARCHAR(100),
    device_model VARCHAR(100),
    os_version VARCHAR(50),
    app_version VARCHAR(50),
    push_provider VARCHAR(20), -- 'fcm', 'apns', 'web_push'
    push_token_encrypted BYTEA,
    push_token_iv BYTEA,
    push_token_auth_tag BYTEA,
    last_ip INET,
    last_country_code CHAR(2),
    last_city VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'revoked', 'expired'
    revoked_at TIMESTAMPTZ,
    revoked_reason VARCHAR(50),
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_user_identifier ON devices (user_id, device_identifier) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices (user_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices (status);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_devices_updated_at ON devices;
CREATE TRIGGER trigger_update_devices_updated_at
    BEFORE UPDATE ON devices
    FOR EACH ROW
    EXECUTE FUNCTION update_devices_updated_at();