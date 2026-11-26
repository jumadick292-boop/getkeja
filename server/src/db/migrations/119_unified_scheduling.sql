-- Migration: 119_unified_scheduling
-- Description: Task 13.9 — shared scheduling, workforce assignment, availability,
--   capacity, rescheduling and reminder state across moving, garbage (incl.
--   recurring occurrences) and laundry. Additive and idempotent. Does NOT own any
--   domain lifecycle; references existing operational resources with enforced FKs
--   and a per-resource uniqueness rule. Provider operating hours / availability
--   exceptions (107) are reused, not duplicated.

CREATE EXTENSION IF NOT EXISTS btree_gist;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'scheduling_domain') THEN
        CREATE TYPE scheduling_domain AS ENUM ('moving', 'garbage', 'garbage_occurrence', 'laundry');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'scheduling_status') THEN
        CREATE TYPE scheduling_status AS ENUM ('proposed', 'confirmed', 'cancelled', 'completed', 'missed');
    END IF;
END $$;

-- scheduling_activities — one shared schedule per schedulable resource.
CREATE TABLE IF NOT EXISTS scheduling_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain scheduling_domain NOT NULL,
    -- Exactly one resource reference is set, matching the domain.
    moving_job_id UUID REFERENCES moving_jobs(id) ON DELETE CASCADE,
    garbage_job_id UUID REFERENCES garbage_jobs(id) ON DELETE CASCADE,
    garbage_occurrence_id UUID REFERENCES garbage_recurring_occurrences(id) ON DELETE CASCADE,
    laundry_order_id UUID REFERENCES laundry_orders(id) ON DELETE CASCADE,
    resource_id UUID NOT NULL,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    time_zone TEXT NOT NULL DEFAULT 'Africa/Nairobi',
    all_day BOOLEAN NOT NULL DEFAULT FALSE,
    status scheduling_status NOT NULL DEFAULT 'confirmed',
    location_id UUID,
    address TEXT,
    customer_user_id UUID REFERENCES users(id) ON DELETE RESTRICT,
    provider_profile_id UUID REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    assigned_staff_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    -- Conflict-detection key (e.g. 'staff:<uuid>' or 'provider:<uuid>'); NULL => unconstrained.
    capacity_key TEXT,
    reminder_state VARCHAR(16) NOT NULL DEFAULT 'none',
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_sched_activity_resource CHECK (
        (domain = 'moving' AND moving_job_id IS NOT NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL)
        OR (domain = 'garbage' AND garbage_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL)
        OR (domain = 'garbage_occurrence' AND garbage_occurrence_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND laundry_order_id IS NULL)
        OR (domain = 'laundry' AND laundry_order_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL)
    ),
    CONSTRAINT chk_sched_activity_window CHECK (end_at > start_at)
);

-- Exactly one schedule per resource.
CREATE UNIQUE INDEX IF NOT EXISTS uq_sched_activity_moving ON scheduling_activities (moving_job_id) WHERE moving_job_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_sched_activity_garbage ON scheduling_activities (garbage_job_id) WHERE garbage_job_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_sched_activity_occurrence ON scheduling_activities (garbage_occurrence_id) WHERE garbage_occurrence_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_sched_activity_laundry ON scheduling_activities (laundry_order_id) WHERE laundry_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sched_activity_provider ON scheduling_activities (provider_profile_id, start_at);
CREATE INDEX IF NOT EXISTS idx_sched_activity_customer ON scheduling_activities (customer_user_id, start_at);
CREATE INDEX IF NOT EXISTS idx_sched_activity_staff ON scheduling_activities (assigned_staff_user_id, start_at);
CREATE INDEX IF NOT EXISTS idx_sched_activity_window ON scheduling_activities (start_at, end_at);

-- Prevent double-booking a constrained resource (staff/provider) at the DB level.
ALTER TABLE scheduling_activities DROP CONSTRAINT IF EXISTS ex_sched_activity_no_overlap;
ALTER TABLE scheduling_activities ADD CONSTRAINT ex_sched_activity_no_overlap
    EXCLUDE USING gist (
        capacity_key WITH =,
        tstzrange(start_at, end_at) WITH &&
    ) WHERE (status = 'confirmed' AND capacity_key IS NOT NULL);

CREATE OR REPLACE FUNCTION update_scheduling_activities_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_scheduling_activities_updated_at ON scheduling_activities;
CREATE TRIGGER trigger_update_scheduling_activities_updated_at
    BEFORE UPDATE ON scheduling_activities FOR EACH ROW EXECUTE FUNCTION update_scheduling_activities_updated_at();

-- staff_availability — per-user working hours (distinct from provider hours).
CREATE TABLE IF NOT EXISTS staff_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    open_time TIME NOT NULL,
    close_time TIME NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    time_zone TEXT NOT NULL DEFAULT 'Africa/Nairobi',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_staff_availability_window CHECK (close_time > open_time OR NOT is_available)
);
CREATE INDEX IF NOT EXISTS idx_staff_availability_user ON staff_availability (user_id, day_of_week);

-- staff_leave — temporary staff unavailability.
CREATE TABLE IF NOT EXISTS staff_leave (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_staff_leave_range CHECK (end_date >= start_date)
);
CREATE INDEX IF NOT EXISTS idx_staff_leave_user ON staff_leave (user_id, start_date, end_date);

-- scheduling_capacity — provider/offering capacity + booking rules.
CREATE TABLE IF NOT EXISTS scheduling_capacity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE CASCADE,
    offering_id UUID REFERENCES provider_service_offerings(id) ON DELETE CASCADE,
    capacity_per_slot INTEGER NOT NULL DEFAULT 1,
    slot_minutes INTEGER NOT NULL DEFAULT 60,
    buffer_minutes INTEGER NOT NULL DEFAULT 0,
    min_notice_minutes INTEGER NOT NULL DEFAULT 0,
    max_advance_days INTEGER NOT NULL DEFAULT 365,
    time_zone TEXT NOT NULL DEFAULT 'Africa/Nairobi',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_capacity_values CHECK (
        capacity_per_slot > 0 AND slot_minutes > 0 AND buffer_minutes >= 0
        AND min_notice_minutes >= 0 AND max_advance_days > 0
    )
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_scheduling_capacity_profile_offering
    ON scheduling_capacity (provider_profile_id, COALESCE(offering_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- staff_assignments — shared assignment to an activity (+ history).
CREATE TABLE IF NOT EXISTS staff_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES scheduling_activities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    label VARCHAR(120),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_staff_assignment_active
    ON staff_assignments (activity_id, user_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_staff_assignments_user ON staff_assignments (user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_staff_assignments_activity ON staff_assignments (activity_id, is_active);

CREATE TABLE IF NOT EXISTS staff_assignment_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES scheduling_activities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    action VARCHAR(32) NOT NULL,
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_staff_assignment_history_activity ON staff_assignment_history (activity_id, created_at DESC);

-- reschedule_requests — propose/approve/reject; original schedule kept until approval.
CREATE TABLE IF NOT EXISTS reschedule_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES scheduling_activities(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    requesting_party VARCHAR(16) NOT NULL,
    requested_start_at TIMESTAMPTZ NOT NULL,
    requested_end_at TIMESTAMPTZ NOT NULL,
    reason TEXT,
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    decided_by UUID REFERENCES users(id) ON DELETE SET NULL,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_reschedule_party CHECK (requesting_party IN ('customer', 'provider')),
    CONSTRAINT chk_reschedule_status CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    CONSTRAINT chk_reschedule_window CHECK (requested_end_at > requested_start_at)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_reschedule_pending_per_activity
    ON reschedule_requests (activity_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_reschedule_activity ON reschedule_requests (activity_id, created_at DESC);

-- scheduling_reminders — reminder state per activity (idempotent worker).
CREATE TABLE IF NOT EXISTS scheduling_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES scheduling_activities(id) ON DELETE CASCADE,
    remind_at TIMESTAMPTZ NOT NULL,
    state VARCHAR(16) NOT NULL DEFAULT 'pending',
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_scheduling_reminders_activity
    ON scheduling_reminders (activity_id);
CREATE INDEX IF NOT EXISTS idx_scheduling_reminders_due ON scheduling_reminders (state, remind_at);