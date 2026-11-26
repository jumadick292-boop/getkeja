-- Migration: 127_finishing_operations
-- Description: Task 13.15 — shared Finishing & Building Services operational
--   module built on the 13.5 marketplace, 13.4 provider catalogue, 13.9 scheduling
--   and 13.10 communications. One operational job per accepted marketplace
--   quotation, with site inspection/measurement, work plans & checklists,
--   materials/finish records, quality inspections & corrective work, amendments,
--   staff assignments, exceptions, before/after evidence and append-only history.
--   Additive and idempotent. Categories in scope: roofing, flooring, tiling,
--   painting, painting_decoration.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'finishing_operation_status') THEN
        CREATE TYPE finishing_operation_status AS ENUM (
            'confirmed', 'assessment_scheduled', 'awaiting_assessment',
            'assessment_in_progress', 'plan_prepared', 'awaiting_customer_approval',
            'scheduled', 'assigned', 'materials_prepared', 'in_progress',
            'awaiting_materials', 'quality_inspection', 'awaiting_handover',
            'completed_pending_confirmation', 'completed', 'cancelled', 'failed',
            'exception'
        );
    END IF;
END $$;

-- finishing_jobs — one operational job per accepted marketplace quotation.
CREATE TABLE IF NOT EXISTS finishing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE RESTRICT,
    quotation_id UUID NOT NULL REFERENCES service_quotations(id) ON DELETE RESTRICT,
    quotation_version INTEGER NOT NULL,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    assigned_staff_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status finishing_operation_status NOT NULL DEFAULT 'confirmed',
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
    assessment_required BOOLEAN NOT NULL DEFAULT TRUE,
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
CREATE UNIQUE INDEX IF NOT EXISTS uq_finishing_jobs_request
    ON finishing_jobs (service_request_id);
CREATE INDEX IF NOT EXISTS idx_finishing_jobs_customer
    ON finishing_jobs (customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_finishing_jobs_provider
    ON finishing_jobs (provider_profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_finishing_jobs_staff
    ON finishing_jobs (assigned_staff_user_id);

-- Append-only operational history.
CREATE TABLE IF NOT EXISTS finishing_job_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES finishing_jobs(id) ON DELETE CASCADE,
    action VARCHAR(64) NOT NULL,
    previous_status finishing_operation_status,
    new_status finishing_operation_status,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_finishing_history_job
    ON finishing_job_history (job_id, created_at);

-- Site inspection / measurement (customer-visible report vs internal notes).
CREATE TABLE IF NOT EXISTS finishing_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES finishing_jobs(id) ON DELETE CASCADE,
    assessor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'scheduled',
    scheduled_at TIMESTAMPTZ,
    findings TEXT,
    measurements TEXT,
    site_readiness TEXT,
    recommended_scope TEXT,
    estimated_duration_minutes INTEGER,
    safety_concerns TEXT,
    customer_visible_report TEXT,
    internal_notes TEXT,
    photo_document_ids UUID[] NOT NULL DEFAULT '{}'::uuid[],
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_finishing_assessments_job
    ON finishing_assessments (job_id, created_at);

-- Work plan / task checklist.
CREATE TABLE IF NOT EXISTS finishing_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES finishing_jobs(id) ON DELETE CASCADE,
    summary TEXT NOT NULL,
    steps JSONB NOT NULL DEFAULT '[]'::jsonb,
    deliverables TEXT,
    scheduled_at TIMESTAMPTZ,
    status VARCHAR(32) NOT NULL DEFAULT 'proposed',
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_finishing_plans_job
    ON finishing_plans (job_id, created_at);

-- Materials / finishes (job-level operational record only).
CREATE TABLE IF NOT EXISTS finishing_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES finishing_jobs(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    category VARCHAR(48) NOT NULL DEFAULT 'material',
    quantity NUMERIC(12, 2) NOT NULL DEFAULT 1,
    unit VARCHAR(32) NOT NULL DEFAULT 'unit',
    finish_or_spec TEXT,
    supplied_by VARCHAR(16) NOT NULL DEFAULT 'provider',
    proposed_cost NUMERIC(12, 2),
    approval_status VARCHAR(24) NOT NULL DEFAULT 'pending',
    install_status VARCHAR(24) NOT NULL DEFAULT 'pending',
    customer_visible BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_finishing_materials_job
    ON finishing_materials (job_id, created_at);

-- Quality inspections (incl. corrective work / reinspection).
CREATE TABLE IF NOT EXISTS finishing_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES finishing_jobs(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    outcome VARCHAR(24) NOT NULL DEFAULT 'pending',
    details TEXT,
    corrective_work TEXT,
    customer_visible BOOLEAN NOT NULL DEFAULT TRUE,
    inspected_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_finishing_inspections_job
    ON finishing_inspections (job_id, created_at);

-- Authorized staff (revocable, history preserved).
CREATE TABLE IF NOT EXISTS finishing_staff_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES finishing_jobs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(120),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX uq_finishing_staff_active
    ON finishing_staff_assignments (job_id, user_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_finishing_staff_job
    ON finishing_staff_assignments (job_id, is_active);

-- Amendments (scope/price change) — accepted quotation stays immutable.
CREATE TABLE IF NOT EXISTS finishing_amendments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES finishing_jobs(id) ON DELETE CASCADE,
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
CREATE INDEX IF NOT EXISTS idx_finishing_amendments_job
    ON finishing_amendments (job_id, created_at);

-- Exceptions / interruptions (e.g. weather, site conditions).
CREATE TABLE IF NOT EXISTS finishing_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES finishing_jobs(id) ON DELETE CASCADE,
    reported_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    type VARCHAR(48) NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_finishing_exceptions_job
    ON finishing_exceptions (job_id, created_at);

-- Evidence attachments (before/after, private documents).
CREATE TABLE IF NOT EXISTS finishing_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES finishing_jobs(id) ON DELETE CASCADE,
    document_id UUID NOT NULL,
    kind VARCHAR(48) NOT NULL DEFAULT 'evidence',
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_finishing_attachments_job
    ON finishing_attachments (job_id, created_at);

-- Extend scheduling domain enum with finishing (idempotent).
ALTER TYPE scheduling_domain ADD VALUE IF NOT EXISTS 'finishing';

-- Permissions.
INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.finishing.view', 'View Finishing Jobs', 'View assigned finishing jobs', 'provider', FALSE),
    ('provider.finishing.view_locations', 'View Finishing Locations', 'View service addresses', 'provider', FALSE),
    ('provider.finishing.update_progress', 'Update Finishing Progress', 'Advance job stages', 'provider', FALSE),
    ('provider.finishing.manage_assessments', 'Manage Finishing Assessments', 'Record site inspections and measurements', 'provider', FALSE),
    ('provider.finishing.manage_plans', 'Manage Finishing Plans', 'Prepare work plans and checklists', 'provider', FALSE),
    ('provider.finishing.manage_schedule', 'Manage Finishing Schedule', 'Schedule/reschedule work', 'provider', FALSE),
    ('provider.finishing.upload_evidence', 'Upload Finishing Evidence', 'Upload inspection/handover evidence', 'provider', FALSE),
    ('provider.finishing.assign_staff', 'Assign Finishing Staff', 'Assign authorized operatives', 'provider', FALSE),
    ('provider.finishing.propose_changes', 'Propose Finishing Changes', 'Propose amendments and materials', 'provider', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('service_provider')
   AND p.id IN (
     'provider.finishing.view', 'provider.finishing.view_locations',
     'provider.finishing.update_progress', 'provider.finishing.manage_assessments',
     'provider.finishing.manage_plans', 'provider.finishing.manage_schedule',
     'provider.finishing.upload_evidence', 'provider.finishing.assign_staff',
     'provider.finishing.propose_changes'
   )
ON CONFLICT (role_id, permission_id) DO NOTHING;