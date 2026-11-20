-- Migration: 017_create_phone_login_otp_table
-- Description: Create phone_login_otp table for phone OTP login

CREATE TABLE IF NOT EXISTS phone_login_otp (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    login_identity_id UUID NOT NULL REFERENCES user_login_identities(id) ON DELETE CASCADE,
    otp_hash VARCHAR(64) NOT NULL, -- SHA-256 hex of the OTP code
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    attempt_count INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phone_login_otp_user_id ON phone_login_otp (user_id);
CREATE INDEX IF NOT EXISTS idx_phone_login_otp_login_identity ON phone_login_otp (login_identity_id);
CREATE INDEX IF NOT EXISTS idx_phone_login_otp_expires_at ON phone_login_otp (expires_at);