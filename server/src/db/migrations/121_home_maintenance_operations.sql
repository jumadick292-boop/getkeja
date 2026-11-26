-- Migration: 121_home_maintenance_operations
-- Description: Task 13.12 — shared Home Maintenance & Repairs operational module
--   built on the 13.5 marketplace, 13.4 provider catalogue, 13.9 scheduling and
--   13.10 communications. One operational job per accepted marketplace quotation,
--   with inspection/diagnosis, work plans, materials/parts, amendments,
--   staff assignments, exceptions, evidence and append-only history. Additive and
--   idempotent. Categories in scope: plumbing_*, electrical_*, hvac_service,
--   appliance_repair, handyman, carpentry.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'home_maintenance_status') THEN
        CREATE TYPE home_maintenance_status AS ENUM (
            'confirmed', 'inspection_scheduled', 'awaiting_inspection',
            'inspection_in_progress', 'awaiting_customer_approval', 'work_scheduled',
            'assigned', 'in_progress', 'awaiting_parts', 'awaiting_customer_decision',
            'quality_check', 'completed_pending_confirmation', 'completed',
            'cancelled', 'failed', 'exception'
        );
    END IF;
END $$;

-- home_maintenance_jobs — one operational job per accepted marketplace quotation.
CREATE TABLE IF NOT EXISTS home_maintenance_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE RESTRICT,
    quotation_id UUID NOT NULL REFERENCES service_quotations(id) ON DELETE RESTRICT,
    quotation_version INTEGER NOT NULL,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    assigned_staff_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status home_maintenance_status NOT NULL DEFAULT 'confirmed',
    category_id TEXT NOT NULL,
    domain TEXT NOT NULL,
    property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    service_address TEXT,
    service_latitude DECIMAL(10, 8),
    service_longitude DECIMAL(11, 8),
    agreed_price NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'KES',
    scope JSONB NOT NULL DEFAULT '{}'::jsonb,
    inspection_required BOOLEAN NOT NULL DEFAULT FALSE,
    customer_approval_required BOOLEAN NOT NULL DEFAULT TRUE,
    completion_notes TEXT,
    completion_submitted_at TIMESTAMPTZ,
    customer_confirmation_status VARCHAR(32) NOT NULL DEFAULT 'pending',
    customer_confirmation_notes TEXT,
    customer_confirmation_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    failed_at TIMESTAMPTZ,
    failure_reason TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_home_maintenance_jobs_request
    ON home_maintenance_jobs (service_request_id);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_jobs_customer
    ON home_maintenance_jobs (customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_jobs_provider
    ON home_maintenance_jobs (provider_profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_jobs_staff
    ON home_maintenance_jobs (assigned_staff_user_id);

-- Append-only operational history.
CREATE TABLE IF NOT EXISTS home_maintenance_job_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES home_maintenance_jobs(id) ON DELETE CASCADE,
    action VARCHAR(64) NOT NULL,
    previous_status home_maintenance_status,
    new_status home_maintenance_status,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_history_job
    ON home_maintenance_job_history (job_id, created_at);

-- Inspection / diagnosis records (customer-visible report vs internal notes).
CREATE TABLE IF NOT EXISTS home_maintenance_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES home_maintenance_jobs(id) ON DELETE CASCADE,
    technician_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'scheduled',
    scheduled_at TIMESTAMPTZ,
    findings TEXT,
    diagnosis TEXT,
    recommended_work TEXT,
    estimated_duration_minutes INTEGER,
    materials_required TEXT,
    safety_concerns TEXT,
    customer_visible_report TEXT,
    internal_notes TEXT,
    photo_document_ids UUID[] NOT NULL DEFAULT '{}'::uuid[],
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_inspections_job
    ON home_maintenance_inspections (job_id, created_at);

-- Work plan.
CREATE TABLE IF NOT EXISTS home_maintenance_work_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES home_maintenance_jobs(id) ON DELETE CASCADE,
    summary TEXT NOT NULL,
    steps JSONB NOT NULL DEFAULT '[]'::jsonb,
    scheduled_at TIMESTAMPTZ,
    status VARCHAR(32) NOT NULL DEFAULT 'proposed',
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_work_plans_job
    ON home_maintenance_work_plans (job_id, created_at);

-- Materials / parts.
CREATE TABLE IF NOT EXISTS home_maintenance_parts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES home_maintenance_jobs(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    quantity NUMERIC(12, 2) NOT NULL DEFAULT 1,
    unit VARCHAR(32) NOT NULL DEFAULT 'unit',
    model_spec TEXT,
    supplied_by VARCHAR(16) NOT NULL DEFAULT 'provider',
    proposed_cost NUMERIC(12, 2),
    approval_status VARCHAR(24) NOT NULL DEFAULT 'pending',
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_parts_job
    ON home_maintenance_parts (job_id, created_at);

-- Authorized staff (revocable, history preserved).
CREATE TABLE IF NOT EXISTS home_maintenance_staff_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES home_maintenance_jobs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(120),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX uq_home_maintenance_staff_active
    ON home_maintenance_staff_assignments (job_id, user_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_home_maintenance_staff_job
    ON home_maintenance_staff_assignments (job_id, is_active);

-- Amendments (scope/price change) — accepted quotation stays immutable.
CREATE TABLE IF NOT EXISTS home_maintenance_amendments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES home_maintenance_jobs(id) ON DELETE CASCADE,
    proposed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL,
    revised_scope JSONB NOT NULL DEFAULT '{}'::jsonb,
    additional_cost NUMERIC(12, 2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'KES',
    status VARCHAR(24) NOT NULL DEFAULT 'pending',
    decided_by UUID REFERENCES users(id) ON DELETE SET NULL,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_amendments_job
    ON home_maintenance_amendments (job_id, created_at);

-- Exceptions.
CREATE TABLE IF NOT EXISTS home_maintenance_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES home_maintenance_jobs(id) ON DELETE CASCADE,
    reported_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    type VARCHAR(48) NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_exceptions_job
    ON home_maintenance_exceptions (job_id, created_at);

-- Evidence attachments (private documents).
CREATE TABLE IF NOT EXISTS home_maintenance_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES home_maintenance_jobs(id) ON DELETE CASCADE,
    document_id UUID NOT NULL,
    kind VARCHAR(48) NOT NULL DEFAULT 'evidence',
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_home_maintenance_attachments_job
    ON home_maintenance_attachments (job_id, created_at);

-- Extend scheduling domain enum with home_maintenance (idempotent).
ALTER TYPE scheduling_domain ADD VALUE IF NOT EXISTS 'home_maintenance';

-- Permissions.
INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.home_maintenance.view', 'View Maintenance Jobs', 'View assigned maintenance jobs', 'provider', FALSE),
    ('provider.home_maintenance.view_locations', 'View Maintenance Locations', 'View service addresses', 'provider', FALSE),
    ('provider.home_maintenance.update_progress', 'Update Maintenance Progress', 'Advance job stages', 'provider', FALSE),
    ('provider.home_maintenance.manage_inspections', 'Manage Inspections', 'Record inspections and diagnoses', 'provider', FALSE),
    ('provider.home_maintenance.manage_schedule', 'Manage Maintenance Schedule', 'Schedule/reschedule work', 'provider', FALSE),
    ('provider.home_maintenance.upload_evidence', 'Upload Maintenance Evidence', 'Upload inspection/completion evidence', 'provider', FALSE),
    ('provider.home_maintenance.assign_staff', 'Assign Maintenance Staff', 'Assign authorized technicians', 'provider', FALSE),
    ('provider.home_maintenance.propose_changes', 'Propose Maintenance Changes', 'Propose amendments and parts', 'provider', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('service_provider')
   AND p.id IN (
     'provider.home_maintenance.view', 'provider.home_maintenance.view_locations',
     'provider.home_maintenance.update_progress', 'provider.home_maintenance.manage_inspections',
     'provider.home_maintenance.manage_schedule', 'provider.home_maintenance.upload_evidence',
     'provider.home_maintenance.assign_staff', 'provider.home_maintenance.propose_changes'
   )
ON CONFLICT (role_id, permission_id) DO NOTHING;