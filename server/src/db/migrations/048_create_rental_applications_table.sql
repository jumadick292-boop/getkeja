-- Migration: 048_create_rental_applications_table
-- Description: Create rental_applications table for tenant applications before tenancy creation

CREATE TYPE application_status AS ENUM (
    'submitted', 'under_review', 'approved', 'rejected', 'withdrawn',
    'pending_documents', 'pending_payment', 'expired'
);

CREATE TABLE IF NOT EXISTS rental_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    -- Applicant (can be existing user or new)
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    applicant_name VARCHAR(255) NOT NULL,
    applicant_email VARCHAR(255) NOT NULL,
    applicant_phone VARCHAR(50) NOT NULL,
    applicant_id_number VARCHAR(50),
    applicant_id_type VARCHAR(30),
    -- Application details
    status application_status NOT NULL DEFAULT 'submitted',
    preferred_start_date DATE,
    preferred_end_date DATE,
    proposed_rent_amount DECIMAL(12, 2),
    -- Documents
    documents JSONB, -- Array of document references
    -- References
    employer_name VARCHAR(255),
    employer_contact VARCHAR(255),
    monthly_income DECIMAL(12, 2),
    previous_landlord_name VARCHAR(255),
    previous_landlord_contact VARCHAR(255),
    -- Guarantor
    guarantor_name VARCHAR(255),
    guarantor_email VARCHAR(255),
    guarantor_phone VARCHAR(50),
    guarantor_id_number VARCHAR(50),
    guarantor_relationship VARCHAR(50),
    -- Review
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,
    rejection_reason TEXT,
    -- Approval
    approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    approved_rent_amount DECIMAL(12, 2),
    approved_deposit_amount DECIMAL(12, 2),
    approved_start_date DATE,
    approved_end_date DATE,
    -- Tenancy creation
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_dates CHECK (preferred_end_date IS NULL OR preferred_end_date >= preferred_start_date)
);

CREATE INDEX IF NOT EXISTS idx_rental_applications_property_id ON rental_applications (property_id);
CREATE INDEX IF NOT EXISTS idx_rental_applications_unit_id ON rental_applications (unit_id);
CREATE INDEX IF NOT EXISTS idx_rental_applications_user_id ON rental_applications (user_id);
CREATE INDEX IF NOT EXISTS idx_rental_applications_status ON rental_applications (status);
CREATE INDEX IF NOT EXISTS idx_rental_applications_email ON rental_applications (applicant_email);
CREATE INDEX IF NOT EXISTS idx_rental_applications_created_at ON rental_applications (created_at DESC);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_rental_applications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_rental_applications_updated_at ON rental_applications;
CREATE TRIGGER trigger_update_rental_applications_updated_at
    BEFORE UPDATE ON rental_applications
    FOR EACH ROW
    EXECUTE FUNCTION update_rental_applications_updated_at();

-- Application history (audit)
CREATE TABLE IF NOT EXISTS rental_application_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES rental_applications(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'submitted', 'reviewed', 'approved', 'rejected', 'withdrawn', 'documents_requested'
    previous_status application_status,
    new_status application_status,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rental_application_history_application_id ON rental_application_history (application_id);
CREATE INDEX IF NOT EXISTS idx_rental_application_history_created_at ON rental_application_history (created_at DESC);