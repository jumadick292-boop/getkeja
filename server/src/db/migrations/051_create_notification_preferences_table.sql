-- Migration: 051_create_notification_preferences_table
-- Description: Create notification_preferences table for user-configurable notification settings

CREATE TYPE notification_channel AS ENUM ('email', 'sms', 'push', 'in_app');

CREATE TABLE IF NOT EXISTS notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- Global channel preferences
    email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sms_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    in_app_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    -- Category preferences (can override global)
    security_email BOOLEAN NOT NULL DEFAULT TRUE,      -- MFA, login, password, recovery
    security_sms BOOLEAN NOT NULL DEFAULT TRUE,
    security_push BOOLEAN NOT NULL DEFAULT TRUE,
    security_in_app BOOLEAN NOT NULL DEFAULT TRUE,
    account_email BOOLEAN NOT NULL DEFAULT TRUE,       -- profile changes, verification
    account_sms BOOLEAN NOT NULL DEFAULT TRUE,
    account_push BOOLEAN NOT NULL DEFAULT TRUE,
    account_in_app BOOLEAN NOT NULL DEFAULT TRUE,
    property_email BOOLEAN NOT NULL DEFAULT TRUE,      -- property updates, applications
    property_sms BOOLEAN NOT NULL DEFAULT FALSE,
    property_push BOOLEAN NOT NULL DEFAULT TRUE,
    property_in_app BOOLEAN NOT NULL DEFAULT TRUE,
    tenancy_email BOOLEAN NOT NULL DEFAULT TRUE,       -- tenancy created, payments, renewals
    tenancy_sms BOOLEAN NOT NULL DEFAULT TRUE,
    tenancy_push BOOLEAN NOT NULL DEFAULT TRUE,
    tenancy_in_app BOOLEAN NOT NULL DEFAULT TRUE,
    service_email BOOLEAN NOT NULL DEFAULT TRUE,       -- service provider assignments
    service_sms BOOLEAN NOT NULL DEFAULT FALSE,
    service_push BOOLEAN NOT NULL DEFAULT TRUE,
    service_in_app BOOLEAN NOT NULL DEFAULT TRUE,
    financial_email BOOLEAN NOT NULL DEFAULT TRUE,     -- payments, invoices, refunds
    financial_sms BOOLEAN NOT NULL DEFAULT TRUE,
    financial_push BOOLEAN NOT NULL DEFAULT TRUE,
    financial_in_app BOOLEAN NOT NULL DEFAULT TRUE,
    operational_email BOOLEAN NOT NULL DEFAULT TRUE,   -- maintenance, inspections
    operational_sms BOOLEAN NOT NULL DEFAULT FALSE,
    operational_push BOOLEAN NOT NULL DEFAULT TRUE,
    operational_in_app BOOLEAN NOT NULL DEFAULT TRUE,
    marketing_email BOOLEAN NOT NULL DEFAULT FALSE,    -- promotional (opt-in)
    marketing_sms BOOLEAN NOT NULL DEFAULT FALSE,
    marketing_push BOOLEAN NOT NULL DEFAULT FALSE,
    marketing_in_app BOOLEAN NOT NULL DEFAULT FALSE,
    -- Quiet hours (UTC) for non-critical notifications
    quiet_hours_start TIME, -- e.g., '22:00'
    quiet_hours_end TIME,   -- e.g., '08:00'
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC', -- user's timezone for quiet hours
    -- Metadata for future extensibility
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_id ON notification_preferences (user_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_notification_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_notification_preferences_updated_at ON notification_preferences;
CREATE TRIGGER trigger_update_notification_preferences_updated_at
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_preferences_updated_at();