-- Migration: 087_create_site_visit_availability_and_links
-- Description: Add enquiry link, assignment, and availability rules to site visits

-- Add enquiry_id to site_visits
ALTER TABLE site_visits
    ADD COLUMN IF NOT EXISTS enquiry_id UUID REFERENCES property_enquiries(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_site_visits_enquiry_id ON site_visits (enquiry_id);

-- Add assigned_to_user_id to site_visits
ALTER TABLE site_visits
    ADD COLUMN IF NOT EXISTS assigned_to_user_id UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_site_visits_assigned_to_user ON site_visits (assigned_to_user_id);

-- Site visit availability rules (per property)
CREATE TYPE availability_day_of_week AS ENUM (
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
);

CREATE TABLE IF NOT EXISTS site_visit_availability_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    day_of_week availability_day_of_week NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    slot_duration_minutes INTEGER NOT NULL DEFAULT 30,
    buffer_minutes INTEGER NOT NULL DEFAULT 0,
    max_bookings_per_slot INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (property_id, day_of_week)
);

CREATE INDEX IF NOT EXISTS idx_site_visit_availability_rules_property ON site_visit_availability_rules (property_id);
CREATE INDEX IF NOT EXISTS idx_site_visit_availability_rules_active ON site_visit_availability_rules (property_id, is_active);

-- Site visit availability exceptions (blackout dates / temporary unavailability)
CREATE TABLE IF NOT EXISTS site_visit_availability_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    exception_date DATE NOT NULL,
    reason TEXT,
    is_unavailable BOOLEAN NOT NULL DEFAULT true,
    start_time TIME,
    end_time TIME,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (property_id, exception_date)
);

CREATE INDEX IF NOT EXISTS idx_site_visit_availability_exceptions_property ON site_visit_availability_exceptions (property_id);
CREATE INDEX IF NOT EXISTS idx_site_visit_availability_exceptions_date ON site_visit_availability_exceptions (exception_date);

-- Trigger for availability rules updated_at
CREATE OR REPLACE FUNCTION update_site_visit_availability_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_site_visit_availability_rules_updated_at ON site_visit_availability_rules;
CREATE TRIGGER trigger_update_site_visit_availability_rules_updated_at
    BEFORE UPDATE ON site_visit_availability_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_site_visit_availability_rules_updated_at();

-- Trigger for availability exceptions updated_at
CREATE OR REPLACE FUNCTION update_site_visit_availability_exceptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_site_visit_availability_exceptions_updated_at ON site_visit_availability_exceptions;
CREATE TRIGGER trigger_update_site_visit_availability_exceptions_updated_at
    BEFORE UPDATE ON site_visit_availability_exceptions
    FOR EACH ROW
    EXECUTE FUNCTION update_site_visit_availability_exceptions_updated_at();
