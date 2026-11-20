-- Migration: 022_create_mfa_recovery_codes_table
-- Description: Create mfa_recovery_codes table for storing hashed recovery codes

CREATE TABLE IF NOT EXISTS mfa_recovery_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mfa_method_id UUID NOT NULL REFERENCES mfa_methods(id) ON DELETE CASCADE,
    code_hash VARCHAR(64) NOT NULL, -- SHA-256 hash of the recovery code
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mfa_recovery_codes_user_id ON mfa_recovery_codes (user_id);
CREATE INDEX IF NOT EXISTS idx_mfa_recovery_codes_method_id ON mfa_recovery_codes (mfa_method_id);
CREATE INDEX IF NOT EXISTS idx_mfa_recovery_codes_unused ON mfa_recovery_codes (user_id) WHERE used_at IS NULL;