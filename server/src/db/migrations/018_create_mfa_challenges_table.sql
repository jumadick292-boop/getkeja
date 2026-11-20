-- Migration: 018_create_mfa_challenges_table
-- Description: Create mfa_challenges table for MFA handoff after primary authentication

CREATE TABLE IF NOT EXISTS mfa_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_type VARCHAR(20) NOT NULL, -- 'totp', 'backup_codes', etc.
    challenge_data JSONB NOT NULL, -- encrypted secret, backup codes, etc.
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'completed', 'expired', 'failed'
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    failed_attempts INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mfa_challenges_user_id ON mfa_challenges (user_id);
CREATE INDEX IF NOT EXISTS idx_mfa_challenges_status ON mfa_challenges (status);
CREATE INDEX IF NOT EXISTS idx_mfa_challenges_expires_at ON mfa_challenges (expires_at);