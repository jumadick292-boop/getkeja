-- Migration: 130_provider_complaints
-- Description: Task 13.16 — structured customer complaints / service-quality
--   cases tied to an operational job (resource_domain + resource_id), with a
--   documented lifecycle, customer/provider messages, corrective actions,
--   private platform-admin internal notes, assignment, escalation, resolution
--   and append-only history. A complaint never changes a job's completion status
--   and never triggers financial flows. Additive and idempotent.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'complaint_status') THEN
        CREATE TYPE complaint_status AS ENUM (
            'submitted', 'acknowledged', 'under_review',
            'awaiting_customer_information', 'awaiting_provider_response',
            'resolution_proposed', 'resolved', 'escalated', 'closed'
        );
    END IF;
END $$;

-- Configurable reason catalogue (seeded below).
CREATE TABLE IF NOT EXISTS complaint_reasons (
    id VARCHAR(48) PRIMARY KEY,
    label TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 100
);

CREATE TABLE IF NOT EXISTS complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_domain TEXT NOT NULL,
    resource_id UUID NOT NULL,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    reason_id VARCHAR(48) NOT NULL REFERENCES complaint_reasons(id) ON DELETE RESTRICT,
    description TEXT NOT NULL,
    status complaint_status NOT NULL DEFAULT 'submitted',
    assigned_admin_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    resolution_summary TEXT,
    resolved_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_complaints_customer ON complaints (customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaints_provider ON complaints (provider_profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaints_resource ON complaints (resource_domain, resource_id);
CREATE INDEX IF NOT EXISTS idx_complaints_assignee ON complaints (assigned_admin_user_id);

-- Customer/provider/admin messages on a case.
CREATE TABLE IF NOT EXISTS complaint_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    author_role VARCHAR(24) NOT NULL,
    body TEXT NOT NULL,
    document_ids UUID[] NOT NULL DEFAULT '{}'::uuid[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_complaint_messages_case ON complaint_messages (complaint_id, created_at);

-- Provider corrective actions.
CREATE TABLE IF NOT EXISTS complaint_corrective_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    recorded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_complaint_actions_case ON complaint_corrective_actions (complaint_id, created_at);

-- Private platform-admin internal notes (never exposed to customer/provider).
CREATE TABLE IF NOT EXISTS complaint_internal_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_complaint_notes_case ON complaint_internal_notes (complaint_id, created_at);

-- Append-only status history.
CREATE TABLE IF NOT EXISTS complaint_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    previous_status complaint_status,
    new_status complaint_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_complaint_history_case ON complaint_status_history (complaint_id, created_at);

INSERT INTO complaint_reasons (id, label, sort_order) VALUES
    ('incomplete_work', 'Incomplete work', 10),
    ('poor_workmanship', 'Poor workmanship', 20),
    ('missed_appointment', 'Missed appointment', 30),
    ('property_damage', 'Property damage', 40),
    ('unprofessional_conduct', 'Unprofessional conduct', 50),
    ('miscommunication', 'Miscommunication', 60),
    ('incorrect_scope', 'Incorrect service scope', 70),
    ('other', 'Other service-related issue', 80)
ON CONFLICT (id) DO NOTHING;