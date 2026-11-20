-- Migration: 043_create_unit_access_assignments_table
-- Description: Create unit_access_assignments table for granular unit-level access

CREATE TABLE IF NOT EXISTS unit_access_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    -- Assigned to individual
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    -- Or assigned to organization
    organisation_id UUID REFERENCES organisations(id) ON DELETE CASCADE,
    -- Access details
    access_level VARCHAR(30) NOT NULL DEFAULT 'full', -- 'full', 'view_only', 'maintenance_only', 'inspection_only'
    permissions JSONB, -- Specific permissions for this unit
    -- Status and dates
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'suspended', 'revoked', 'expired'
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    -- Assignment management
    assigned_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_unit_access_target CHECK (
        (user_id IS NOT NULL AND organisation_id IS NULL) OR
        (user_id IS NULL AND organisation_id IS NOT NULL)
    ),
    CONSTRAINT chk_effective_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_unit_access_assignments_unit_id ON unit_access_assignments (unit_id);
CREATE INDEX IF NOT EXISTS idx_unit_access_assignments_property_id ON unit_access_assignments (property_id);
CREATE INDEX IF NOT EXISTS idx_unit_access_assignments_user_id ON unit_access_assignments (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_unit_access_assignments_organisation_id ON unit_access_assignments (organisation_id) WHERE organisation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_unit_access_assignments_status ON unit_access_assignments (status);
CREATE INDEX IF NOT EXISTS idx_unit_access_assignments_effective_dates ON unit_access_assignments (effective_from, effective_to) WHERE status = 'active';

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_unit_access_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_unit_access_assignments_updated_at ON unit_access_assignments;
CREATE TRIGGER trigger_update_unit_access_assignments_updated_at
    BEFORE UPDATE ON unit_access_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_unit_access_assignments_updated_at();

-- Unit access history table (audit)
CREATE TABLE IF NOT EXISTS unit_access_assignment_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES unit_access_assignments(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'created', 'updated', 'suspended', 'revoked', 'expired'
    previous_level VARCHAR(30),
    previous_status VARCHAR(20),
    previous_effective_from TIMESTAMPTZ,
    previous_effective_to TIMESTAMPTZ,
    new_level VARCHAR(30),
    new_status VARCHAR(20),
    new_effective_from TIMESTAMPTZ,
    new_effective_to TIMESTAMPTZ,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_unit_access_history_assignment_id ON unit_access_assignment_history (assignment_id);
CREATE INDEX IF NOT EXISTS idx_unit_access_history_unit_id ON unit_access_assignment_history (unit_id);
CREATE INDEX IF NOT EXISTS idx_unit_access_history_created_at ON unit_access_assignment_history (created_at DESC);