-- Migration: 114_moving_operations
-- Description: Task 13.6 — moving & relocation provider operations. Adds a
--   dedicated moving-job operational record built FROM an accepted marketplace
--   quotation (no new request/quotation engine). Additive and idempotent.
--   Reuses service_requests/service_quotations, saved_locations, conversations,
--   organisation membership and the transactional outbox.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE moving_job_status AS ENUM (
    'confirmed', 'awaiting_customer_details', 'preparation', 'ready_for_move',
    'in_progress', 'arrived_at_destination', 'unloading',
    'awaiting_customer_confirmation', 'completed', 'cancelled', 'failed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE moving_assessment_status AS ENUM (
    'requested', 'accepted', 'declined', 'completed', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE moving_change_status AS ENUM ('pending', 'accepted', 'rejected', 'withdrawn');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- moving_jobs — one per accepted moving request (contractual snapshot).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS moving_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL UNIQUE REFERENCES service_requests(id) ON DELETE CASCADE,
    quotation_id UUID NOT NULL REFERENCES service_quotations(id),
    quotation_version INTEGER NOT NULL,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    assigned_staff_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status moving_job_status NOT NULL DEFAULT 'confirmed',
    -- Origin / destination (location refs + textual fallback snapshot).
    origin_location_id UUID REFERENCES saved_locations(id) ON DELETE SET NULL,
    destination_location_id UUID REFERENCES saved_locations(id) ON DELETE SET NULL,
    origin_address TEXT,
    destination_address TEXT,
    origin_contact_instructions TEXT,
    destination_contact_instructions TEXT,
    origin_building_name VARCHAR(200),
    origin_floor VARCHAR(20),
    origin_lift_available BOOLEAN,
    origin_access_notes TEXT,
    destination_building_name VARCHAR(200),
    destination_floor VARCHAR(20),
    destination_lift_available BOOLEAN,
    destination_access_notes TEXT,
    -- Agreed schedule.
    agreed_move_date DATE,
    agreed_window_start TIME,
    agreed_window_end TIME,
    -- Confirmed scope + commercial snapshot (immutable reference to accepted quote).
    scope JSONB NOT NULL DEFAULT '{}'::jsonb,
    agreed_price NUMERIC(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    checklist JSONB NOT NULL DEFAULT '{}'::jsonb,
    -- Optional tenancy linkage.
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    -- Completion / customer confirmation.
    completion_notes TEXT,
    completion_submitted_at TIMESTAMPTZ,
    completion_outstanding_issue BOOLEAN NOT NULL DEFAULT FALSE,
    customer_confirmation_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    customer_confirmation_notes TEXT,
    customer_confirmation_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    failed_at TIMESTAMPTZ,
    failure_reason TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_moving_job_price_nonneg CHECK (agreed_price >= 0)
);
CREATE INDEX IF NOT EXISTS idx_moving_jobs_customer ON moving_jobs (customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_moving_jobs_provider ON moving_jobs (provider_profile_id, status);
CREATE INDEX IF NOT EXISTS idx_moving_jobs_status ON moving_jobs (status, agreed_move_date);
CREATE INDEX IF NOT EXISTS idx_moving_jobs_staff ON moving_jobs (assigned_staff_user_id);

CREATE OR REPLACE FUNCTION update_moving_jobs_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trigger_update_moving_jobs_updated_at ON moving_jobs;
CREATE TRIGGER trigger_update_moving_jobs_updated_at
    BEFORE UPDATE ON moving_jobs FOR EACH ROW EXECUTE FUNCTION update_moving_jobs_updated_at();

-- ---------------------------------------------------------------------------
-- moving_job_history — append-only operational + status audit.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS moving_job_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moving_job_id UUID NOT NULL REFERENCES moving_jobs(id) ON DELETE CASCADE,
    action VARCHAR(60) NOT NULL,
    previous_status moving_job_status,
    new_status moving_job_status,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_moving_job_history_job ON moving_job_history (moving_job_id, created_at DESC);

CREATE OR REPLACE FUNCTION record_moving_job_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO moving_job_history (moving_job_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trigger_record_moving_job_history ON moving_jobs;
CREATE TRIGGER trigger_record_moving_job_history
    BEFORE UPDATE ON moving_jobs FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_moving_job_history();

-- ---------------------------------------------------------------------------
-- moving_job_staff_assignments — authorized org staff (history preserved).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS moving_job_staff_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moving_job_id UUID NOT NULL REFERENCES moving_jobs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    label VARCHAR(120),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_moving_job_active_staff
    ON moving_job_staff_assignments (moving_job_id, user_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_moving_job_staff_job ON moving_job_staff_assignments (moving_job_id, is_active);

-- ---------------------------------------------------------------------------
-- moving_job_assessments — pre-move surveys (lifecycle mirrors site visits).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS moving_job_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moving_job_id UUID NOT NULL REFERENCES moving_jobs(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    assigned_staff_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status moving_assessment_status NOT NULL DEFAULT 'requested',
    proposed_at TIMESTAMPTZ,
    location_id UUID REFERENCES saved_locations(id) ON DELETE SET NULL,
    location_address TEXT,
    provider_notes TEXT,
    customer_notes TEXT,
    outcome TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_moving_job_assessments_job ON moving_job_assessments (moving_job_id, created_at DESC);

CREATE OR REPLACE FUNCTION update_moving_job_assessments_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trigger_update_moving_job_assessments_updated_at ON moving_job_assessments;
CREATE TRIGGER trigger_update_moving_job_assessments_updated_at
    BEFORE UPDATE ON moving_job_assessments FOR EACH ROW EXECUTE FUNCTION update_moving_job_assessments_updated_at();

-- ---------------------------------------------------------------------------
-- moving_job_schedule_changes — reschedule proposals + immutable accepted history.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS moving_job_schedule_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moving_job_id UUID NOT NULL REFERENCES moving_jobs(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    previous_date DATE,
    previous_window_start TIME,
    previous_window_end TIME,
    proposed_date DATE NOT NULL,
    proposed_window_start TIME,
    proposed_window_end TIME,
    reason TEXT,
    status moving_change_status NOT NULL DEFAULT 'pending',
    decided_by UUID REFERENCES users(id) ON DELETE SET NULL,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_moving_job_schedule_job ON moving_job_schedule_changes (moving_job_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- moving_job_amendments — controlled scope/price change (immutable when accepted).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS moving_job_amendments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moving_job_id UUID NOT NULL REFERENCES moving_jobs(id) ON DELETE CASCADE,
    proposed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL,
    revised_scope JSONB NOT NULL DEFAULT '{}'::jsonb,
    additional_cost NUMERIC(12, 2) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    status moving_change_status NOT NULL DEFAULT 'pending',
    decided_by UUID REFERENCES users(id) ON DELETE SET NULL,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_moving_amendment_cost_nonneg CHECK (additional_cost >= 0)
);
CREATE INDEX IF NOT EXISTS idx_moving_job_amendments_job ON moving_job_amendments (moving_job_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- moving_job_attachments — evidence/assessment/completion (loose document ref).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS moving_job_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moving_job_id UUID NOT NULL REFERENCES moving_jobs(id) ON DELETE CASCADE,
    document_id UUID NOT NULL,
    kind VARCHAR(20) NOT NULL DEFAULT 'evidence',
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (moving_job_id, document_id, kind)
);
CREATE INDEX IF NOT EXISTS idx_moving_job_attachments_job ON moving_job_attachments (moving_job_id);

-- ---------------------------------------------------------------------------
-- conversations link (reuse messaging; additive column).
-- ---------------------------------------------------------------------------
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS moving_job_id UUID REFERENCES moving_jobs(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_conversations_moving_job ON conversations (moving_job_id);

-- ---------------------------------------------------------------------------
-- Provider moving permissions (additive, idempotent) + grant to moving roles.
-- ---------------------------------------------------------------------------
INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.moving.view', 'View Assigned Moving Jobs', 'View assigned moving jobs and scope', 'provider', FALSE),
    ('provider.moving.view_locations', 'View Moving Job Locations', 'View sensitive origin/destination details', 'provider', FALSE),
    ('provider.moving.update_progress', 'Update Moving Job Progress', 'Advance operational status and checklists', 'provider', FALSE),
    ('provider.moving.manage_schedule', 'Manage Moving Schedule', 'Propose rescheduling and confirm schedule', 'provider', FALSE),
    ('provider.moving.upload_evidence', 'Upload Moving Evidence', 'Upload job evidence and completion photos', 'provider', FALSE),
    ('provider.moving.propose_changes', 'Propose Moving Changes', 'Propose scope/price amendments', 'provider', FALSE),
    ('provider.moving.assign_staff', 'Assign Moving Staff', 'Assign authorized organization staff', 'provider', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('moving_company', 'individual_mover', 'service_provider')
   AND p.id IN (
     'provider.moving.view', 'provider.moving.view_locations',
     'provider.moving.update_progress', 'provider.moving.manage_schedule',
     'provider.moving.upload_evidence', 'provider.moving.propose_changes',
     'provider.moving.assign_staff'
   )
ON CONFLICT (role_id, permission_id) DO NOTHING;