-- Migration: 008_create_phone_verification_tokens_table
-- Description: Create phone_verification_tokens table for SMS OTP verification

CREATE TABLE IF NOT EXISTS phone_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    login_identity_id UUID NOT NULL REFERENCES user_login_identities(id) ON DELETE CASCADE,
    otp_hash VARCHAR(64) NOT NULL, -- SHA-256 hex of the OTP code
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    attempt_count INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 5,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phone_verification_tokens_user_id ON phone_verification_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_phone_verification_tokens_login_identity ON phone_verification_tokens (login_identity_id);
CREATE INDEX IF NOT EXISTS idx_phone_verification_tokens_expires_at ON phone_verification_tokens (expires_at);