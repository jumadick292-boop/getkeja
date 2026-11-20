-- Migration: 033_create_role_assignments_table
-- Description: Create role_assignments table with explicit scope model (global, organization, resource)

CREATE TYPE role_assignment_scope AS ENUM ('global', 'organization', 'resource');

CREATE TABLE IF NOT EXISTS role_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id VARCHAR(50) NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    scope role_assignment_scope NOT NULL DEFAULT 'global',
    organization_id UUID REFERENCES organisations(id) ON DELETE CASCADE,
    resource_type VARCHAR(50), -- e.g., 'property', 'unit', 'tenancy', 'service_request'
    resource_id UUID,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL,
    revoked_reason VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_organization_scope CHECK (
        (scope = 'organization' AND organization_id IS NOT NULL) OR
        (scope != 'organization' AND organization_id IS NULL)
    ),
    CONSTRAINT chk_resource_scope CHECK (
        (scope = 'resource' AND resource_type IS NOT NULL AND resource_id IS NOT NULL) OR
        (scope != 'resource' AND resource_type IS NULL AND resource_id IS NULL)
    ),
    CONSTRAINT chk_global_scope CHECK (
        (scope = 'global' AND organization_id IS NULL AND resource_type IS NULL AND resource_id IS NULL) OR
        (scope != 'global')
    )
);

CREATE INDEX IF NOT EXISTS idx_role_assignments_user_id ON role_assignments (user_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_role_assignments_role_id ON role_assignments (role_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_role_assignments_org_id ON role_assignments (organization_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_role_assignments_resource ON role_assignments (resource_type, resource_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_role_assignments_scope ON role_assignments (scope) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_role_assignments_expires_at ON role_assignments (expires_at) WHERE revoked_at IS NULL AND expires_at IS NOT NULL;

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_role_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_role_assignments_updated_at ON role_assignments;
CREATE TRIGGER trigger_update_role_assignments_updated_at
    BEFORE UPDATE ON role_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_role_assignments_updated_at();