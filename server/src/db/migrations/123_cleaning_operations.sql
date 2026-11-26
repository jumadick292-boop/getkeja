-- Migration: 123_cleaning_operations
-- Description: Task 13.13 — shared Cleaning & Property Care operational module
--   built on the 13.5 marketplace, 13.4 provider catalogue, 13.9 scheduling and
--   13.10 communications. One operational job per accepted marketplace quotation,
--   with assessment, checklists, area breakdowns, materials/consumables,
--   amendments, staff assignments, exceptions, before/after evidence and
--   append-only history. Additive and idempotent. Categories in scope:
--   clean_deep, clean_home, clean_office, pest_control_general, gardening,
--   landscaping_general.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'cleaning_operation_status') THEN
        CREATE TYPE cleaning_operation_status AS ENUM (
            'confirmed', 'assessment_scheduled', 'awaiting_assessment',
            'assessment_in_progress', 'scheduled', 'assigned', 'in_progress',
            'awaiting_supplies', 'awaiting_customer_decision', 'quality_check',
            'completed_pending_confirmation', 'completed', 'cancelled', 'failed',
            'exception'
        );
    END IF;
END $$;

-- cleaning_jobs — one operational job per accepted marketplace quotation.
CREATE TABLE IF NOT EXISTS cleaning_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE RESTRICT,
    quotation_id UUID NOT NULL REFERENCES service_quotations(id) ON DELETE RESTRICT,
    quotation_version INTEGER NOT NULL,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    assigned_staff_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status cleaning_operation_status NOT NULL DEFAULT 'confirmed',
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
    assessment_required BOOLEAN NOT NULL DEFAULT FALSE,
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
CREATE UNIQUE INDEX IF NOT EXISTS uq_cleaning_jobs_request
    ON cleaning_jobs (service_request_id);
CREATE INDEX IF NOT EXISTS idx_cleaning_jobs_customer
    ON cleaning_jobs (customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cleaning_jobs_provider
    ON cleaning_jobs (provider_profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cleaning_jobs_staff
    ON cleaning_jobs (assigned_staff_user_id);

-- Append-only operational history.
CREATE TABLE IF NOT EXISTS cleaning_job_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES cleaning_jobs(id) ON DELETE CASCADE,
    action VARCHAR(64) NOT NULL,
    previous_status cleaning_operation_status,
    new_status cleaning_operation_status,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cleaning_history_job
    ON cleaning_job_history (job_id, created_at);

-- Assessment / site survey (customer-visible report vs internal notes).
CREATE TABLE IF NOT EXISTS cleaning_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES cleaning_jobs(id) ON DELETE CASCADE,
    assessor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'scheduled',
    scheduled_at TIMESTAMPTZ,
    findings TEXT,
    scope_assessment TEXT,
    recommended_tasks TEXT,
    estimated_duration_minutes INTEGER,
    supplies_required TEXT,
    safety_concerns TEXT,
    customer_visible_report TEXT,
    internal_notes TEXT,
    photo_document_ids UUID[] NOT NULL DEFAULT '{}'::uuid[],
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cleaning_assessments_job
    ON cleaning_assessments (job_id, created_at);

-- Job checklist (items + completion state).
CREATE TABLE IF NOT EXISTS cleaning_checklists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES cleaning_jobs(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    completed_count INTEGER NOT NULL DEFAULT 0,
    total_count INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(32) NOT NULL DEFAULT 'proposed',
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cleaning_checklists_job
    ON cleaning_checklists (job_id, created_at);

-- Room / area / outdoor-work breakdown.
CREATE TABLE IF NOT EXISTS cleaning_areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES cleaning_jobs(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    area_type VARCHAR(32) NOT NULL DEFAULT 'room',
    approximate_size TEXT,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cleaning_areas_job
    ON cleaning_areas (job_id, created_at);

-- Materials / consumables used (job-level operational record only).
CREATE TABLE IF NOT EXISTS cleaning_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES cleaning_jobs(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    quantity NUMERIC(12, 2) NOT NULL DEFAULT 1,
    unit VARCHAR(32) NOT NULL DEFAULT 'unit',
    supplied_by VARCHAR(16) NOT NULL DEFAULT 'provider',
    proposed_cost NUMERIC(12, 2),
    approval_status VARCHAR(24) NOT NULL DEFAULT 'pending',
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cleaning_materials_job
    ON cleaning_materials (job_id, created_at);

-- Authorized staff (revocable, history preserved).
CREATE TABLE IF NOT EXISTS cleaning_staff_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES cleaning_jobs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(120),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX uq_cleaning_staff_active
    ON cleaning_staff_assignments (job_id, user_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_cleaning_staff_job
    ON cleaning_staff_assignments (job_id, is_active);

-- Amendments (scope/price change) — accepted quotation stays immutable.
CREATE TABLE IF NOT EXISTS cleaning_amendments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES cleaning_jobs(id) ON DELETE CASCADE,
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
CREATE INDEX IF NOT EXISTS idx_cleaning_amendments_job
    ON cleaning_amendments (job_id, created_at);

-- Exceptions.
CREATE TABLE IF NOT EXISTS cleaning_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES cleaning_jobs(id) ON DELETE CASCADE,
    reported_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    type VARCHAR(48) NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cleaning_exceptions_job
    ON cleaning_exceptions (job_id, created_at);

-- Evidence attachments (before/after, private documents).
CREATE TABLE IF NOT EXISTS cleaning_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES cleaning_jobs(id) ON DELETE CASCADE,
    document_id UUID NOT NULL,
    kind VARCHAR(48) NOT NULL DEFAULT 'evidence',
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cleaning_attachments_job
    ON cleaning_attachments (job_id, created_at);

-- Extend scheduling domain enum with cleaning (idempotent).
ALTER TYPE scheduling_domain ADD VALUE IF NOT EXISTS 'cleaning';

-- Permissions.
INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.cleaning.view', 'View Cleaning Jobs', 'View assigned cleaning jobs', 'provider', FALSE),
    ('provider.cleaning.view_locations', 'View Cleaning Locations', 'View service addresses', 'provider', FALSE),
    ('provider.cleaning.update_progress', 'Update Cleaning Progress', 'Advance job stages and checklists', 'provider', FALSE),
    ('provider.cleaning.manage_assessments', 'Manage Assessments', 'Record assessments and findings', 'provider', FALSE),
    ('provider.cleaning.manage_schedule', 'Manage Cleaning Schedule', 'Schedule/reschedule work', 'provider', FALSE),
    ('provider.cleaning.upload_evidence', 'Upload Cleaning Evidence', 'Upload before/after evidence', 'provider', FALSE),
    ('provider.cleaning.assign_staff', 'Assign Cleaning Staff', 'Assign authorized staff', 'provider', FALSE),
    ('provider.cleaning.propose_changes', 'Propose Cleaning Changes', 'Propose amendments and materials', 'provider', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('service_provider')
   AND p.id IN (
     'provider.cleaning.view', 'provider.cleaning.view_locations',
     'provider.cleaning.update_progress', 'provider.cleaning.manage_assessments',
     'provider.cleaning.manage_schedule', 'provider.cleaning.upload_evidence',
     'provider.cleaning.assign_staff', 'provider.cleaning.propose_changes'
   )
ON CONFLICT (role_id, permission_id) DO NOTHING;