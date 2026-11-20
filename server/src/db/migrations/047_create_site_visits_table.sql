-- Migration: 047_create_site_visits_table
-- Description: Create site_visits table for property viewing appointments

CREATE TYPE visit_status AS ENUM ('scheduled', 'confirmed', 'completed', 'cancelled', 'no_show', 'rescheduled');

CREATE TABLE IF NOT EXISTS site_visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    -- Visitor info (can be user or just contact)
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    visitor_name VARCHAR(255) NOT NULL,
    visitor_email VARCHAR(255),
    visitor_phone VARCHAR(50) NOT NULL,
    -- Visit details
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER NOT NULL DEFAULT 30,
    status visit_status NOT NULL DEFAULT 'scheduled',
    -- Agent/host
    hosted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    hosted_by_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    -- Notes
    visitor_notes TEXT,
    host_notes TEXT,
    outcome VARCHAR(50), -- 'interested', 'not_interested', 'application_submitted', 'other'
    -- Metadata
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_site_visits_property_id ON site_visits (property_id);
CREATE INDEX IF NOT EXISTS idx_site_visits_unit_id ON site_visits (unit_id);
CREATE INDEX IF NOT EXISTS idx_site_visits_user_id ON site_visits (user_id);
CREATE INDEX IF NOT EXISTS idx_site_visits_scheduled_at ON site_visits (scheduled_at);
CREATE INDEX IF NOT EXISTS idx_site_visits_status ON site_visits (status);
CREATE INDEX IF NOT EXISTS idx_site_visits_hosted_by_user ON site_visits (hosted_by_user_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_site_visits_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_site_visits_updated_at ON site_visits;
CREATE TRIGGER trigger_update_site_visits_updated_at
    BEFORE UPDATE ON site_visits
    FOR EACH ROW
    EXECUTE FUNCTION update_site_visits_updated_at();

-- Visit history (audit)
CREATE TABLE IF NOT EXISTS site_visit_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    visit_id UUID NOT NULL REFERENCES site_visits(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'scheduled', 'confirmed', 'completed', 'cancelled', 'rescheduled'
    previous_status visit_status,
    previous_scheduled_at TIMESTAMPTZ,
    new_status visit_status,
    new_scheduled_at TIMESTAMPTZ,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_site_visit_history_visit_id ON site_visit_history (visit_id);
CREATE INDEX IF NOT EXISTS idx_site_visit_history_created_at ON site_visit_history (created_at DESC);