-- Migration: 023_create_security_events_table
-- Description: Create security_events table for audit logging of security-sensitive operations

CREATE TABLE IF NOT EXISTS security_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type VARCHAR(50) NOT NULL, -- 'mfa_enrolled', 'mfa_verified', 'mfa_failed', 'mfa_disabled', 'mfa_method_added', 'mfa_method_removed', 'recovery_code_used', 'recovery_codes_regenerated', 'account_recovery_initiated', 'account_recovery_completed', 'admin_mfa_verified', 'suspicious_activity'
    event_category VARCHAR(20) NOT NULL DEFAULT 'mfa', -- 'mfa', 'auth', 'account', 'admin'
    severity VARCHAR(10) NOT NULL DEFAULT 'info', -- 'info', 'warning', 'critical'
    ip_address INET,
    user_agent TEXT,
    metadata JSONB NOT NULL DEFAULT '{}', -- event-specific details
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_events_user_id ON security_events (user_id);
CREATE INDEX IF NOT EXISTS idx_security_events_type ON security_events (event_type);
CREATE INDEX IF NOT EXISTS idx_security_events_category ON security_events (event_category);
CREATE INDEX IF NOT EXISTS idx_security_events_created_at ON security_events (created_at);
CREATE INDEX IF NOT EXISTS idx_security_events_severity ON security_events (severity);