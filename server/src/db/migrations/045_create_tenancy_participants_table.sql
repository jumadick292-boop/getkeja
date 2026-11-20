-- Migration: 045_create_tenancy_participants_table
-- Description: Create tenancy_participants table for tenants and other parties in a tenancy

CREATE TYPE participant_role AS ENUM ('primary_tenant', 'co_tenant', 'guarantor', 'emergency_contact', 'authorized_representative');

CREATE TABLE IF NOT EXISTS tenancy_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
    -- Participant can be a user or just contact info
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    -- For non-user participants (guarantors, emergency contacts)
    full_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(50),
    id_number VARCHAR(50),
    id_type VARCHAR(30), -- 'national_id', 'passport', 'alien_id'
    -- Role and permissions
    role participant_role NOT NULL DEFAULT 'co_tenant',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    can_access_documents BOOLEAN NOT NULL DEFAULT TRUE,
    can_receive_notices BOOLEAN NOT NULL DEFAULT TRUE,
    can_authorize_repairs BOOLEAN NOT NULL DEFAULT FALSE,
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'removed', 'replaced'
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    -- Metadata
    added_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    removed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_participant_identity CHECK (
        (user_id IS NOT NULL) OR (full_name IS NOT NULL AND (email IS NOT NULL OR phone IS NOT NULL))
    )
);

CREATE INDEX IF NOT EXISTS idx_tenancy_participants_tenancy_id ON tenancy_participants (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_tenancy_participants_user_id ON tenancy_participants (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tenancy_participants_role ON tenancy_participants (role);
CREATE INDEX IF NOT EXISTS idx_tenancy_participants_status ON tenancy_participants (status);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_tenancy_participants_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_tenancy_participants_updated_at ON tenancy_participants;
CREATE TRIGGER trigger_update_tenancy_participants_updated_at
    BEFORE UPDATE ON tenancy_participants
    FOR EACH ROW
    EXECUTE FUNCTION update_tenancy_participants_updated_at();

-- Participant history table (audit)
CREATE TABLE IF NOT EXISTS tenancy_participant_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participant_id UUID NOT NULL REFERENCES tenancy_participants(id) ON DELETE CASCADE,
    tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'added', 'removed', 'role_changed', 'permissions_changed'
    previous_role participant_role,
    previous_status VARCHAR(20),
    previous_permissions JSONB,
    new_role participant_role,
    new_status VARCHAR(20),
    new_permissions JSONB,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tenancy_participant_history_participant_id ON tenancy_participant_history (participant_id);
CREATE INDEX IF NOT EXISTS idx_tenancy_participant_history_tenancy_id ON tenancy_participant_history (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_tenancy_participant_history_created_at ON tenancy_participant_history (created_at DESC);