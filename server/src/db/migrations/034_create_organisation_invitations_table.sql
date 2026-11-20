-- Migration: 034_create_organisation_invitations_table
-- Description: Create organisation_invitations table for secure member invitations

CREATE TABLE IF NOT EXISTS organisation_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL, -- 'owner', 'admin', 'member', 'staff'
    invited_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'expired', 'revoked'
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    accepted_by UUID REFERENCES users(id) ON DELETE SET NULL,
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL,
    revoked_reason VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_org_invitations_unique_pending 
    ON organisation_invitations (organisation_id, email) 
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_org_invitations_org_id ON organisation_invitations (organisation_id);
CREATE INDEX IF NOT EXISTS idx_org_invitations_email ON organisation_invitations (email);
CREATE INDEX IF NOT EXISTS idx_org_invitations_token_hash ON organisation_invitations (token_hash);
CREATE INDEX IF NOT EXISTS idx_org_invitations_status ON organisation_invitations (status);
CREATE INDEX IF NOT EXISTS idx_org_invitations_expires_at ON organisation_invitations (expires_at) WHERE status = 'pending';

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_organisation_invitations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_organisation_invitations_updated_at ON organisation_invitations;
CREATE TRIGGER trigger_update_organisation_invitations_updated_at
    BEFORE UPDATE ON organisation_invitations
    FOR EACH ROW
    EXECUTE FUNCTION update_organisation_invitations_updated_at();