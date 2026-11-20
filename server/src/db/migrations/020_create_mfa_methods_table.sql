-- Migration: 020_create_mfa_methods_table
-- Description: Create mfa_methods table for tracking user MFA methods

CREATE TABLE IF NOT EXISTS mfa_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    method_type VARCHAR(20) NOT NULL, -- 'totp', 'sms', 'email', 'recovery_codes'
    method_name VARCHAR(100), -- user-friendly name like 'Google Authenticator', 'Phone +254712345678'
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}', -- method-specific data (phone number, email, etc.)
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mfa_methods_user_primary ON mfa_methods (user_id) WHERE is_primary AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_mfa_methods_user_id ON mfa_methods (user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_mfa_methods_type ON mfa_methods (method_type) WHERE deleted_at IS NULL;

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_mfa_methods_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_mfa_methods_updated_at ON mfa_methods;
CREATE TRIGGER trigger_update_mfa_methods_updated_at
    BEFORE UPDATE ON mfa_methods
    FOR EACH ROW
    EXECUTE FUNCTION update_mfa_methods_updated_at();