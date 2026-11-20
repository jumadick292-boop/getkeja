-- Migration: 053_create_notification_outbox_table
-- Description: Create notification_outbox table for transactional outbox pattern

CREATE TYPE outbox_status AS ENUM (
    'pending',     -- waiting to be processed
    'processing',  -- worker picked up
    'completed',   -- all delivery jobs created
    'failed',      -- processing failed
    'dead_letter'  -- moved to dead letter after max retries
);

CREATE TABLE IF NOT EXISTS notification_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key VARCHAR(255) NOT NULL UNIQUE, -- prevents duplicate processing
    event_type VARCHAR(100) NOT NULL, -- e.g., 'password_changed', 'new_login', 'tenancy_created'
    category VARCHAR(50) NOT NULL, -- 'security', 'account', 'property', 'tenancy', etc.
    priority VARCHAR(20) NOT NULL DEFAULT 'normal', -- 'low', 'normal', 'high', 'critical'
    recipient_user_ids UUID[] NOT NULL DEFAULT '{}', -- array of user IDs to notify
    organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    resource_type VARCHAR(50), -- 'property', 'unit', 'tenancy', 'application', etc.
    resource_id UUID, -- reference to the business resource
    payload JSONB NOT NULL DEFAULT '{}', -- template variables, metadata
    channels TEXT[] NOT NULL DEFAULT '{}', -- requested channels: 'email', 'sms', 'push', 'in_app'
    status outbox_status NOT NULL DEFAULT 'pending',
    processing_started_at TIMESTAMPTZ,
    processing_completed_at TIMESTAMPTZ,
    error_message TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    next_retry_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_outbox_status ON notification_outbox (status) WHERE status IN ('pending', 'processing');
CREATE INDEX IF NOT EXISTS idx_outbox_idempotency ON notification_outbox (idempotency_key);
CREATE INDEX IF NOT EXISTS idx_outbox_next_retry ON notification_outbox (next_retry_at) WHERE next_retry_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_outbox_created_at ON notification_outbox (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_outbox_event_type ON notification_outbox (event_type);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_notification_outbox_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_notification_outbox_updated_at ON notification_outbox;
CREATE TRIGGER trigger_update_notification_outbox_updated_at
    BEFORE UPDATE ON notification_outbox
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_outbox_updated_at();