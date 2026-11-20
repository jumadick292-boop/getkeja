-- Migration: 052_create_notification_delivery_attempts_table
-- Description: Create notification_delivery_attempts table for tracking delivery status

CREATE TYPE delivery_status AS ENUM (
    'pending',     -- queued for delivery
    'sent',        -- accepted by provider
    'delivered',   -- confirmed delivered by provider
    'failed',      -- failed permanently
    'bounced',     -- email bounced / SMS undeliverable
    'complained',  -- spam complaint
    'suppressed'   -- provider suppressed
);

CREATE TABLE IF NOT EXISTS notification_delivery_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES users(id) ON DELETE SET NULL, -- for multi-recipient notifications
    channel VARCHAR(20) NOT NULL, -- 'email', 'sms', 'push', 'in_app'
    provider VARCHAR(50) NOT NULL, -- e.g., 'sendgrid', 'twilio', 'fcm', 'apns', 'web_push'
    attempt_number INTEGER NOT NULL DEFAULT 1,
    status delivery_status NOT NULL DEFAULT 'pending',
    provider_message_id VARCHAR(255), -- provider's message ID
    provider_response JSONB, -- raw provider response
    error_code VARCHAR(50), -- provider error code if failed
    error_message TEXT, -- sanitized error description
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_attempts_notification_id ON notification_delivery_attempts (notification_id);
CREATE INDEX IF NOT EXISTS idx_delivery_attempts_recipient_id ON notification_delivery_attempts (recipient_id) WHERE recipient_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_delivery_attempts_status ON notification_delivery_attempts (status) WHERE status IN ('pending', 'sent');
CREATE INDEX IF NOT EXISTS idx_delivery_attempts_next_retry ON notification_delivery_attempts (next_retry_at) WHERE next_retry_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_delivery_attempts_channel ON notification_delivery_attempts (channel);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_delivery_attempts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_delivery_attempts_updated_at ON notification_delivery_attempts;
CREATE TRIGGER trigger_update_delivery_attempts_updated_at
    BEFORE UPDATE ON notification_delivery_attempts
    FOR EACH ROW
    EXECUTE FUNCTION update_delivery_attempts_updated_at();

-- Dead letter table for permanently failed deliveries
CREATE TABLE IF NOT EXISTS notification_dead_letters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_attempt_id UUID NOT NULL REFERENCES notification_delivery_attempts(id) ON DELETE CASCADE,
    notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES users(id) ON DELETE SET NULL,
    channel VARCHAR(20) NOT NULL,
    provider VARCHAR(50) NOT NULL,
    failure_reason TEXT NOT NULL,
    payload JSONB NOT NULL, -- the notification payload that failed
    retry_count INTEGER NOT NULL DEFAULT 0,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dead_letters_notification_id ON notification_dead_letters (notification_id);
CREATE INDEX IF NOT EXISTS idx_dead_letters_resolved ON notification_dead_letters (resolved) WHERE resolved = FALSE;
CREATE INDEX IF NOT EXISTS idx_dead_letters_created_at ON notification_dead_letters (created_at DESC);