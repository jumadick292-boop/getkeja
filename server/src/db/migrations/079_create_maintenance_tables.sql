-- Migration: 079_create_maintenance_tables
-- Description: Create property issues and maintenance management tables

CREATE TYPE issue_category AS ENUM ('plumbing', 'electrical', 'water_supply', 'security', 'structural', 'cleaning', 'fixtures', 'pest_control', 'hvac', 'appliances', 'other');
CREATE TYPE issue_priority AS ENUM ('low', 'medium', 'high', 'urgent', 'emergency');
CREATE TYPE issue_status AS ENUM ('new', 'acknowledged', 'under_assessment', 'awaiting_approval', 'approved', 'assigned', 'in_progress', 'awaiting_parts_access', 'resolved', 'closed', 'rejected', 'cancelled');
CREATE TYPE maintenance_type AS ENUM ('repair', 'inspection', 'preventive', 'emergency', 'renovation', 'cleaning', 'other');

CREATE TABLE IF NOT EXISTS property_issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reporter_role VARCHAR(30) NOT NULL, -- 'landlord', 'manager', 'caretaker', 'tenant', 'agent'
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category issue_category NOT NULL,
    priority issue_priority NOT NULL DEFAULT 'medium',
    status issue_status NOT NULL DEFAULT 'new',
    assigned_to_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_to_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    estimated_cost DECIMAL(12, 2),
    actual_cost DECIMAL(12, 2),
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    resolution_notes TEXT,
    resolved_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_issue_estimated_cost CHECK (estimated_cost IS NULL OR estimated_cost >= 0),
    CONSTRAINT chk_issue_actual_cost CHECK (actual_cost IS NULL OR actual_cost >= 0)
);

CREATE INDEX IF NOT EXISTS idx_property_issues_property_id ON property_issues (property_id);
CREATE INDEX IF NOT EXISTS idx_property_issues_unit_id ON property_issues (unit_id);
CREATE INDEX IF NOT EXISTS idx_property_issues_tenancy_id ON property_issues (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_property_issues_reporter_id ON property_issues (reporter_id);
CREATE INDEX IF NOT EXISTS idx_property_issues_category ON property_issues (category);
CREATE INDEX IF NOT EXISTS idx_property_issues_priority ON property_issues (priority);
CREATE INDEX IF NOT EXISTS idx_property_issues_status ON property_issues (status);
CREATE INDEX IF NOT EXISTS idx_property_issues_assigned_to ON property_issues (assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_property_issues_created_at ON property_issues (created_at DESC);

CREATE TABLE IF NOT EXISTS maintenance_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID NOT NULL REFERENCES property_issues(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    maintenance_type maintenance_type NOT NULL,
    description TEXT NOT NULL,
    status issue_status NOT NULL DEFAULT 'new',
    assigned_to_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_to_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    estimated_cost DECIMAL(12, 2),
    approved_cost DECIMAL(12, 2),
    actual_cost DECIMAL(12, 2),
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    scheduled_date DATE,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    resolution_notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_maintenance_estimated_cost CHECK (estimated_cost IS NULL OR estimated_cost >= 0),
    CONSTRAINT chk_maintenance_approved_cost CHECK (approved_cost IS NULL OR approved_cost >= 0),
    CONSTRAINT chk_maintenance_actual_cost CHECK (actual_cost IS NULL OR actual_cost >= 0)
);

CREATE INDEX IF NOT EXISTS idx_maintenance_requests_issue_id ON maintenance_requests (issue_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_property_id ON maintenance_requests (property_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_unit_id ON maintenance_requests (unit_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_type ON maintenance_requests (maintenance_type);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_status ON maintenance_requests (status);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_assigned_to ON maintenance_requests (assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_created_at ON maintenance_requests (created_at DESC);

CREATE TABLE IF NOT EXISTS maintenance_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    maintenance_request_id UUID NOT NULL REFERENCES maintenance_requests(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    organisation_id UUID REFERENCES organisations(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_maintenance_assignments_request_id ON maintenance_assignments (maintenance_request_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_assignments_user_id ON maintenance_assignments (user_id);

CREATE TABLE IF NOT EXISTS maintenance_estimates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    maintenance_request_id UUID NOT NULL REFERENCES maintenance_requests(id) ON DELETE CASCADE,
    provider_name VARCHAR(255),
    description TEXT NOT NULL,
    estimated_cost DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    valid_until DATE,
    status VARCHAR(30) NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    submitted_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_maintenance_estimate_cost CHECK (estimated_cost > 0)
);

CREATE INDEX IF NOT EXISTS idx_maintenance_estimates_request_id ON maintenance_estimates (maintenance_request_id);

CREATE TABLE IF NOT EXISTS maintenance_approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    maintenance_request_id UUID NOT NULL REFERENCES maintenance_requests(id) ON DELETE CASCADE,
    estimate_id UUID REFERENCES maintenance_estimates(id) ON DELETE SET NULL,
    approved_amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    approved_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    conditions TEXT,
    CONSTRAINT chk_maintenance_approval_amount CHECK (approved_amount > 0)
);

CREATE INDEX IF NOT EXISTS idx_maintenance_approvals_request_id ON maintenance_approvals (maintenance_request_id);

CREATE TABLE IF NOT EXISTS maintenance_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    maintenance_request_id UUID NOT NULL REFERENCES maintenance_requests(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size_bytes BIGINT,
    mime_type VARCHAR(100),
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_maintenance_attachments_request_id ON maintenance_attachments (maintenance_request_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_property_issues_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_property_issues_updated_at ON property_issues;
CREATE TRIGGER trigger_update_property_issues_updated_at
    BEFORE UPDATE ON property_issues
    FOR EACH ROW
    EXECUTE FUNCTION update_property_issues_updated_at();

CREATE OR REPLACE FUNCTION update_maintenance_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_maintenance_requests_updated_at ON maintenance_requests;
CREATE TRIGGER trigger_update_maintenance_requests_updated_at
    BEFORE UPDATE ON maintenance_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_maintenance_requests_updated_at();

-- Maintenance status history table
CREATE TABLE IF NOT EXISTS maintenance_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    maintenance_request_id UUID NOT NULL REFERENCES maintenance_requests(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    previous_status issue_status,
    new_status issue_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_maintenance_status_history_request_id ON maintenance_status_history (maintenance_request_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_status_history_created_at ON maintenance_status_history (created_at DESC);

CREATE OR REPLACE FUNCTION record_maintenance_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO maintenance_status_history (maintenance_request_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_maintenance_status_history ON maintenance_requests;
CREATE TRIGGER trigger_record_maintenance_status_history
    BEFORE UPDATE ON maintenance_requests
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_maintenance_status_history();
