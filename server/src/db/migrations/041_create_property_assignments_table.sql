-- Migration: 041_create_property_assignments_table
-- Description: Create property_assignments table for property managers, caretakers, letting agents

CREATE TYPE assignment_type AS ENUM ('property_manager', 'caretaker', 'letting_agent', 'maintenance', 'security', 'other');

CREATE TABLE IF NOT EXISTS property_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    assignment_type assignment_type NOT NULL,
    -- Assigned to individual
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    -- Or assigned to organization (e.g., agency)
    organisation_id UUID REFERENCES organisations(id) ON DELETE CASCADE,
    -- Assignment details
    scope_description TEXT, -- e.g., "All units", "Units 101-105", "Block A only"
    permissions JSONB, -- Specific permissions for this assignment
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
    CONSTRAINT chk_assignment_target CHECK (
        (user_id IS NOT NULL AND organisation_id IS NULL) OR
        (user_id IS NULL AND organisation_id IS NOT NULL)
    ),
    CONSTRAINT chk_effective_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_property_assignments_property_id ON property_assignments (property_id);
CREATE INDEX IF NOT EXISTS idx_property_assignments_user_id ON property_assignments (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_property_assignments_organisation_id ON property_assignments (organisation_id) WHERE organisation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_property_assignments_type ON property_assignments (assignment_type);
CREATE INDEX IF NOT EXISTS idx_property_assignments_status ON property_assignments (status);
CREATE INDEX IF NOT EXISTS idx_property_assignments_effective_dates ON property_assignments (effective_from, effective_to) WHERE status = 'active';

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_property_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_property_assignments_updated_at ON property_assignments;
CREATE TRIGGER trigger_update_property_assignments_updated_at
    BEFORE UPDATE ON property_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_property_assignments_updated_at();

-- Assignment history table (audit)
CREATE TABLE IF NOT EXISTS property_assignment_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES property_assignments(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'created', 'updated', 'suspended', 'revoked', 'expired'
    previous_type assignment_type,
    previous_status VARCHAR(20),
    previous_scope TEXT,
    previous_effective_from TIMESTAMPTZ,
    previous_effective_to TIMESTAMPTZ,
    new_type assignment_type,
    new_status VARCHAR(20),
    new_scope TEXT,
    new_effective_from TIMESTAMPTZ,
    new_effective_to TIMESTAMPTZ,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_property_assignment_history_assignment_id ON property_assignment_history (assignment_id);
CREATE INDEX IF NOT EXISTS idx_property_assignment_history_property_id ON property_assignment_history (property_id);
CREATE INDEX IF NOT EXISTS idx_property_assignment_history_created_at ON property_assignment_history (created_at DESC);