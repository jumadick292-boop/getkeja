-- Migration: 049_create_notification_templates_table
-- Description: Create notification_templates table for reusable notification templates

CREATE TABLE IF NOT EXISTS notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_key VARCHAR(100) NOT NULL UNIQUE, -- e.g., 'account.password_changed', 'security.new_login'
    event_type VARCHAR(100) NOT NULL, -- e.g., 'password_changed', 'new_login'
    channel VARCHAR(20) NOT NULL, -- 'email', 'sms', 'push', 'in_app'
    locale VARCHAR(10) NOT NULL DEFAULT 'en', -- e.g., 'en', 'sw'
    subject VARCHAR(255), -- for email/push
    body TEXT NOT NULL, -- template with placeholders like {{userName}}, {{timestamp}}
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    version INTEGER NOT NULL DEFAULT 1,
    metadata JSONB NOT NULL DEFAULT '{}', -- additional channel-specific config
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_templates_key ON notification_templates (template_key);
CREATE INDEX IF NOT EXISTS idx_notification_templates_event_channel ON notification_templates (event_type, channel);
CREATE INDEX IF NOT EXISTS idx_notification_templates_active ON notification_templates (is_active) WHERE is_active = TRUE;

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_notification_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_notification_templates_updated_at ON notification_templates;
CREATE TRIGGER trigger_update_notification_templates_updated_at
    BEFORE UPDATE ON notification_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_templates_updated_at();

-- Notification template history table (audit)
CREATE TABLE IF NOT EXISTS notification_template_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES notification_templates(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'created', 'updated', 'activated', 'deactivated'
    previous_template JSONB,
    new_template JSONB,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_template_history_template_id ON notification_template_history (template_id);
CREATE INDEX IF NOT EXISTS idx_notification_template_history_created_at ON notification_template_history (created_at DESC);