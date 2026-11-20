-- Migration: 021_create_mfa_totp_secrets_table
-- Description: Create mfa_totp_secrets table for storing encrypted TOTP secrets with replay prevention

CREATE TABLE IF NOT EXISTS mfa_totp_secrets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mfa_method_id UUID NOT NULL REFERENCES mfa_methods(id) ON DELETE CASCADE,
    encrypted_secret BYTEA NOT NULL, -- AES-256-GCM encrypted TOTP secret
    algorithm VARCHAR(10) NOT NULL DEFAULT 'SHA1',
    digits INT NOT NULL DEFAULT 6,
    period INT NOT NULL DEFAULT 30,
    last_used_step BIGINT NOT NULL DEFAULT -1, -- for replay prevention
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mfa_totp_secrets_user_id ON mfa_totp_secrets (user_id);
CREATE INDEX IF NOT EXISTS idx_mfa_totp_secrets_method_id ON mfa_totp_secrets (mfa_method_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_mfa_totp_secrets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_mfa_totp_secrets_updated_at ON mfa_totp_secrets;
CREATE TRIGGER trigger_update_mfa_totp_secrets_updated_at
    BEFORE UPDATE ON mfa_totp_secrets
    FOR EACH ROW
    EXECUTE FUNCTION update_mfa_totp_secrets_updated_at();