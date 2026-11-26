-- Migration: 075_create_enquiry_tables
-- Description: Create property enquiry and CRM tables for prospective renter management

CREATE TYPE enquiry_status AS ENUM ('new', 'contacted', 'interested', 'site_visit_requested', 'site_visit_scheduled', 'site_visit_completed', 'rental_terms_discussed', 'offer_sent', 'offer_accepted', 'rental_arrangement_confirmed', 'onboarding_initiated', 'converted_to_tenant', 'lost_declined', 'closed');
CREATE TYPE enquiry_source AS ENUM ('public_listing', 'property_detail', 'site_visit_request', 'agency_representative', 'walk_in', 'referral', 'other');

CREATE TABLE IF NOT EXISTS property_enquiries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    listing_id UUID REFERENCES property_listings(id) ON DELETE SET NULL,
    prospective_renter_id UUID REFERENCES users(id) ON DELETE SET NULL,
    prospective_renter_name VARCHAR(255) NOT NULL,
    prospective_renter_email VARCHAR(254),
    prospective_renter_phone VARCHAR(50),
    enquiry_source enquiry_source NOT NULL DEFAULT 'other',
    message TEXT,
    status enquiry_status NOT NULL DEFAULT 'new',
    assigned_to_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_to_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    follow_up_date TIMESTAMPTZ,
    internal_notes TEXT,
    last_contact_at TIMESTAMPTZ,
    converted_to_tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    converted_to_tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_enquiry_followup CHECK (follow_up_date IS NULL OR follow_up_date >= created_at)
);

CREATE INDEX IF NOT EXISTS idx_property_enquiries_property_id ON property_enquiries (property_id);
CREATE INDEX IF NOT EXISTS idx_property_enquiries_unit_id ON property_enquiries (unit_id);
CREATE INDEX IF NOT EXISTS idx_property_enquiries_listing_id ON property_enquiries (listing_id);
CREATE INDEX IF NOT EXISTS idx_property_enquiries_status ON property_enquiries (status);
CREATE INDEX IF NOT EXISTS idx_property_enquiries_assigned_to ON property_enquiries (assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_property_enquiries_created_at ON property_enquiries (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_property_enquiries_prospective_renter ON property_enquiries (prospective_renter_id);

CREATE TABLE IF NOT EXISTS enquiry_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enquiry_id UUID NOT NULL REFERENCES property_enquiries(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    previous_status enquiry_status,
    new_status enquiry_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_enquiry_status_history_enquiry_id ON enquiry_status_history (enquiry_id);
CREATE INDEX IF NOT EXISTS idx_enquiry_status_history_created_at ON enquiry_status_history (created_at DESC);

CREATE TABLE IF NOT EXISTS enquiry_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enquiry_id UUID NOT NULL REFERENCES property_enquiries(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    organisation_id UUID REFERENCES organisations(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL,
    revoked_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_enquiry_assignments_enquiry_id ON enquiry_assignments (enquiry_id);
CREATE INDEX IF NOT EXISTS idx_enquiry_assignments_user_id ON enquiry_assignments (user_id);

CREATE TABLE IF NOT EXISTS enquiry_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enquiry_id UUID NOT NULL REFERENCES property_enquiries(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    note TEXT NOT NULL,
    is_internal BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_enquiry_notes_enquiry_id ON enquiry_notes (enquiry_id);
CREATE INDEX IF NOT EXISTS idx_enquiry_notes_created_at ON enquiry_notes (created_at DESC);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_property_enquiries_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_property_enquiries_updated_at ON property_enquiries;
CREATE TRIGGER trigger_update_property_enquiries_updated_at
    BEFORE UPDATE ON property_enquiries
    FOR EACH ROW
    EXECUTE FUNCTION update_property_enquiries_updated_at();

-- Trigger for enquiry status history
CREATE OR REPLACE FUNCTION record_enquiry_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO enquiry_status_history (enquiry_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_enquiry_status_history ON property_enquiries;
CREATE TRIGGER trigger_record_enquiry_status_history
    BEFORE UPDATE ON property_enquiries
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_enquiry_status_history();
