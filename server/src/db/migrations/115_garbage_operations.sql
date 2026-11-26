-- Migration: 115_garbage_operations
-- Description: Task 13.7 — garbage collection operations built on the 13.5
--   marketplace and 13.6 operational pattern. Additive and idempotent.
--   Authoritative provider identity is specialized_profiles + organisations;
--   legacy garbage_providers/garbage_collection_requests are left untouched.

DO $$ BEGIN
  CREATE TYPE garbage_collection_status AS ENUM (
    'confirmed', 'scheduled', 'provider_assigned', 'en_route', 'arrived',
    'collecting', 'completed', 'awaiting_customer_confirmation',
    'cancelled', 'missed', 'failed', 'rescheduled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE garbage_agreement_status AS ENUM (
    'proposed', 'active', 'suspended', 'completed', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE garbage_occurrence_status AS ENUM (
    'scheduled', 'completed', 'missed', 'cancelled', 'failed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- garbage_jobs — one operational collection per accepted request OR occurrence.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS garbage_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    recurring_occurrence_id UUID,
    agreement_id UUID,
    quotation_id UUID REFERENCES service_quotations(id),
    quotation_version INTEGER,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    assigned_staff_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status garbage_collection_status NOT NULL DEFAULT 'confirmed',
    collection_location_id UUID REFERENCES saved_locations(id) ON DELETE SET NULL,
    collection_address TEXT,
    property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    waste_category VARCHAR(80),
    estimated_quantity VARCHAR(120),
    bin_count INTEGER,
    agreed_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    scope JSONB NOT NULL DEFAULT '{}'::jsonb,
    checklist JSONB NOT NULL DEFAULT '{}'::jsonb,
    scheduled_date DATE,
    window_start TIME,
    window_end TIME,
    completion_notes TEXT,
    completion_submitted_at TIMESTAMPTZ,
    completion_outstanding_issue BOOLEAN NOT NULL DEFAULT FALSE,
    customer_confirmation_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    customer_confirmation_notes TEXT,
    customer_confirmation_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    missed_at TIMESTAMPTZ,
    missed_reason TEXT,
    failed_at TIMESTAMPTZ,
    failure_reason TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_garbage_job_source CHECK (service_request_id IS NOT NULL OR recurring_occurrence_id IS NOT NULL),
    CONSTRAINT chk_garbage_job_price_nonneg CHECK (agreed_price >= 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_garbage_jobs_request ON garbage_jobs (service_request_id) WHERE service_request_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_garbage_jobs_occurrence ON garbage_jobs (recurring_occurrence_id) WHERE recurring_occurrence_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_garbage_jobs_customer ON garbage_jobs (customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_garbage_jobs_provider ON garbage_jobs (provider_profile_id, status);
CREATE INDEX IF NOT EXISTS idx_garbage_jobs_status ON garbage_jobs (status, scheduled_date);
CREATE INDEX IF NOT EXISTS idx_garbage_jobs_staff ON garbage_jobs (assigned_staff_user_id);

CREATE OR REPLACE FUNCTION update_garbage_jobs_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trigger_update_garbage_jobs_updated_at ON garbage_jobs;
CREATE TRIGGER trigger_update_garbage_jobs_updated_at
    BEFORE UPDATE ON garbage_jobs FOR EACH ROW EXECUTE FUNCTION update_garbage_jobs_updated_at();

-- ---------------------------------------------------------------------------
-- garbage_job_history — append-only audit (+ status trigger).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS garbage_job_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    garbage_job_id UUID NOT NULL REFERENCES garbage_jobs(id) ON DELETE CASCADE,
    action VARCHAR(60) NOT NULL,
    previous_status garbage_collection_status,
    new_status garbage_collection_status,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_garbage_job_history_job ON garbage_job_history (garbage_job_id, created_at DESC);

CREATE OR REPLACE FUNCTION record_garbage_job_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO garbage_job_history (garbage_job_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trigger_record_garbage_job_history ON garbage_jobs;
CREATE TRIGGER trigger_record_garbage_job_history
    BEFORE UPDATE ON garbage_jobs FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_garbage_job_history();

-- ---------------------------------------------------------------------------
-- Staff, attachments, exceptions.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS garbage_job_staff_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    garbage_job_id UUID NOT NULL REFERENCES garbage_jobs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    label VARCHAR(120),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_garbage_job_active_staff
    ON garbage_job_staff_assignments (garbage_job_id, user_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_garbage_job_staff_job ON garbage_job_staff_assignments (garbage_job_id, is_active);

CREATE TABLE IF NOT EXISTS garbage_job_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    garbage_job_id UUID NOT NULL REFERENCES garbage_jobs(id) ON DELETE CASCADE,
    document_id UUID NOT NULL,
    kind VARCHAR(20) NOT NULL DEFAULT 'evidence',
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (garbage_job_id, document_id, kind)
);
CREATE INDEX IF NOT EXISTS idx_garbage_job_attachments_job ON garbage_job_attachments (garbage_job_id);

CREATE TABLE IF NOT EXISTS garbage_job_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    garbage_job_id UUID NOT NULL REFERENCES garbage_jobs(id) ON DELETE CASCADE,
    reported_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    type VARCHAR(40) NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_garbage_job_exceptions_job ON garbage_job_exceptions (garbage_job_id);

-- ---------------------------------------------------------------------------
-- Recurring agreements + occurrences (idempotent generation).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS garbage_recurring_agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID REFERENCES service_requests(id) ON DELETE SET NULL,
    quotation_id UUID REFERENCES service_quotations(id),
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    status garbage_agreement_status NOT NULL DEFAULT 'proposed',
    frequency VARCHAR(20) NOT NULL DEFAULT 'weekly',
    interval_days INTEGER,
    days_of_week INTEGER[] NOT NULL DEFAULT '{}',
    window_start TIME,
    window_end TIME,
    start_date DATE NOT NULL,
    end_date DATE,
    agreed_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    billing_frequency VARCHAR(20),
    waste_category VARCHAR(80),
    scope JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_garbage_agreement_dates CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_garbage_agreement_amount_nonneg CHECK (agreed_amount >= 0)
);
CREATE INDEX IF NOT EXISTS idx_garbage_agreements_customer ON garbage_recurring_agreements (customer_user_id, status);
CREATE INDEX IF NOT EXISTS idx_garbage_agreements_provider ON garbage_recurring_agreements (provider_profile_id, status);

CREATE TABLE IF NOT EXISTS garbage_recurring_occurrences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_id UUID NOT NULL REFERENCES garbage_recurring_agreements(id) ON DELETE CASCADE,
    period_key DATE NOT NULL,
    scheduled_date DATE NOT NULL,
    window_start TIME,
    window_end TIME,
    status garbage_occurrence_status NOT NULL DEFAULT 'scheduled',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (agreement_id, period_key)
);
CREATE INDEX IF NOT EXISTS idx_garbage_occurrences_agreement ON garbage_recurring_occurrences (agreement_id, scheduled_date);

-- Deferred FKs (circular between jobs <-> occurrences/agreements).
ALTER TABLE garbage_jobs DROP CONSTRAINT IF EXISTS fk_garbage_job_occurrence;
ALTER TABLE garbage_jobs ADD CONSTRAINT fk_garbage_job_occurrence
    FOREIGN KEY (recurring_occurrence_id) REFERENCES garbage_recurring_occurrences(id) ON DELETE CASCADE;
ALTER TABLE garbage_jobs DROP CONSTRAINT IF EXISTS fk_garbage_job_agreement;
ALTER TABLE garbage_jobs ADD CONSTRAINT fk_garbage_job_agreement
    FOREIGN KEY (agreement_id) REFERENCES garbage_recurring_agreements(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- Provider garbage permissions (additive) + grant to garbage roles.
-- ---------------------------------------------------------------------------
INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.garbage.view', 'View Assigned Garbage Collections', 'View assigned garbage collections', 'provider', FALSE),
    ('provider.garbage.view_locations', 'View Collection Locations', 'View exact collection addresses', 'provider', FALSE),
    ('provider.garbage.update_progress', 'Update Collection Progress', 'Advance collection status and checklists', 'provider', FALSE),
    ('provider.garbage.manage_schedule', 'Manage Collection Schedule', 'Propose rescheduling', 'provider', FALSE),
    ('provider.garbage.upload_evidence', 'Upload Collection Evidence', 'Upload completion evidence', 'provider', FALSE),
    ('provider.garbage.assign_staff', 'Assign Collection Staff', 'Assign authorized staff', 'provider', FALSE),
    ('provider.garbage.manage_agreements', 'Manage Recurring Agreements', 'Propose and manage recurring agreements', 'provider', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('garbage_provider', 'service_provider')
   AND p.id IN (
     'provider.garbage.view', 'provider.garbage.view_locations',
     'provider.garbage.update_progress', 'provider.garbage.manage_schedule',
     'provider.garbage.upload_evidence', 'provider.garbage.assign_staff',
     'provider.garbage.manage_agreements'
   )
ON CONFLICT (role_id, permission_id) DO NOTHING;