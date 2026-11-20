-- Migration: 040_create_property_ownerships_table
-- Description: Create property_ownerships table for tracking property ownership

CREATE TYPE ownership_type AS ENUM ('individual', 'corporate', 'joint', 'trust');

CREATE TABLE IF NOT EXISTS property_ownerships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    owner_type ownership_type NOT NULL DEFAULT 'individual',
    -- For individual owners
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    -- For corporate/trust owners
    organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    -- For joint ownership - percentage share
    ownership_share DECIMAL(5, 2) NOT NULL DEFAULT 100.00, -- e.g., 50.00 for 50%
    -- Verification
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    verification_notes TEXT,
    -- Dates
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ, -- NULL means current ownership
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'transferred', 'disputed', 'terminated'
    -- Metadata
    title_deed_reference VARCHAR(255),
    title_deed_image_url VARCHAR(500),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_owner_type CHECK (
        (owner_type = 'individual' AND user_id IS NOT NULL AND organisation_id IS NULL) OR
        (owner_type IN ('corporate', 'trust') AND organisation_id IS NOT NULL AND user_id IS NULL) OR
        (owner_type = 'joint' AND ((user_id IS NOT NULL) OR (organisation_id IS NOT NULL)))
    ),
    CONSTRAINT chk_ownership_share CHECK (ownership_share > 0 AND ownership_share <= 100),
    CONSTRAINT chk_effective_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_property_ownerships_property_id ON property_ownerships (property_id);
CREATE INDEX IF NOT EXISTS idx_property_ownerships_user_id ON property_ownerships (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_property_ownerships_organisation_id ON property_ownerships (organisation_id) WHERE organisation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_property_ownerships_status ON property_ownerships (status);
CREATE INDEX IF NOT EXISTS idx_property_ownerships_effective_dates ON property_ownerships (effective_from, effective_to);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_property_ownerships_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_property_ownerships_updated_at ON property_ownerships;
CREATE TRIGGER trigger_update_property_ownerships_updated_at
    BEFORE UPDATE ON property_ownerships
    FOR EACH ROW
    EXECUTE FUNCTION update_property_ownerships_updated_at();

-- Ownership history table (audit)
CREATE TABLE IF NOT EXISTS property_ownership_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ownership_id UUID NOT NULL REFERENCES property_ownerships(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'created', 'transferred', 'verified', 'disputed', 'terminated'
    previous_owner_type ownership_type,
    previous_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    previous_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    previous_share DECIMAL(5, 2),
    previous_status VARCHAR(20),
    new_owner_type ownership_type,
    new_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    new_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    new_share DECIMAL(5, 2),
    new_status VARCHAR(20),
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_property_ownership_history_ownership_id ON property_ownership_history (ownership_id);
CREATE INDEX IF NOT EXISTS idx_property_ownership_history_property_id ON property_ownership_history (property_id);
CREATE INDEX IF NOT EXISTS idx_property_ownership_history_created_at ON property_ownership_history (created_at DESC);