-- Migration: 050_create_notifications_table
-- Description: Create notifications table for in-app and multi-channel notifications

CREATE TYPE notification_category AS ENUM (
    'security',      -- MFA, login, password, recovery
    'account',       -- profile changes, verification
    'property',      -- property updates, applications
    'tenancy',       -- tenancy created, payments, renewals
    'service',       -- service provider assignments
    'financial',     -- payments, invoices, refunds
    'operational',   -- maintenance, inspections
    'marketing'      -- promotional (opt-in required)
);

CREATE TYPE notification_priority AS ENUM (
    'low',
    'normal',
    'high',
    'critical'
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    event_type VARCHAR(100) NOT NULL, -- e.g., 'password_changed', 'new_login', 'tenancy_created'
    category notification_category NOT NULL DEFAULT 'operational',
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}', -- resource references, deep links, etc.
    priority notification_priority NOT NULL DEFAULT 'normal',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_org_id ON notifications (organisation_id) WHERE organisation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_category ON notifications (category);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications (user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_expires_at ON notifications (expires_at) WHERE expires_at IS NOT NULL;

-- Trigger to update read_at when is_read changes
CREATE OR REPLACE FUNCTION update_notification_read_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_read AND NOT OLD.is_read THEN
        NEW.read_at = NOW();
    ELSIF NOT NEW.is_read AND OLD.is_read THEN
        NEW.read_at = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_notification_read_at ON notifications;
CREATE TRIGGER trigger_update_notification_read_at
    BEFORE UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_read_at();

-- Notification recipients (for multi-recipient notifications)
CREATE TABLE IF NOT EXISTS notification_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    delivered_channels JSONB NOT NULL DEFAULT '[]', -- tracks which channels delivered
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_recipients_notification_id ON notification_recipients (notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_recipients_user_id ON notification_recipients (user_id);
CREATE INDEX IF NOT EXISTS idx_notification_recipients_read ON notification_recipients (user_id, is_read) WHERE is_read = FALSE;