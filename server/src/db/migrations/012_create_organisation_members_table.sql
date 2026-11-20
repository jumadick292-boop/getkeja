-- Migration: 012_create_organisation_members_table
-- Description: Create organisation_members table for organisation membership

CREATE TABLE IF NOT EXISTS organisation_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL, -- 'owner', 'admin', 'member', 'staff'
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'invited', 'suspended', 'removed'
    invited_by UUID REFERENCES users(id) ON DELETE SET NULL,
    invited_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ,
    removed_at TIMESTAMPTZ,
    removed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (organisation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_organisation_members_organisation_id ON organisation_members (organisation_id);
CREATE INDEX IF NOT EXISTS idx_organisation_members_user_id ON organisation_members (user_id);
CREATE INDEX IF NOT EXISTS idx_organisation_members_status ON organisation_members (status);