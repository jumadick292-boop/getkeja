-- Migration: 077_create_rental_proposal_tables
-- Description: Create rental proposal and negotiation tables

CREATE TYPE rental_proposal_status AS ENUM ('draft', 'sent', 'under_review', 'changes_requested', 'accepted', 'declined', 'expired', 'withdrawn', 'confirmed');
CREATE TYPE rental_proposal_type AS ENUM ('new_tenancy', 'renewal', 'rent_increase', 'terms_change');

CREATE TABLE IF NOT EXISTS rental_proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enquiry_id UUID REFERENCES property_enquiries(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    prospective_renter_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    landlord_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    type rental_proposal_type NOT NULL DEFAULT 'new_tenancy',
    status rental_proposal_status NOT NULL DEFAULT 'draft',
    proposed_rent_amount DECIMAL(12, 2) NOT NULL,
    proposed_deposit_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    proposed_start_date DATE NOT NULL,
    proposed_end_date DATE,
    proposed_rent_due_day INTEGER NOT NULL DEFAULT 1,
    special_conditions TEXT,
    notes TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    declined_at TIMESTAMPTZ,
    withdrawn_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_proposal_dates CHECK (proposed_end_date IS NULL OR proposed_end_date >= proposed_start_date),
    CONSTRAINT chk_proposal_rent CHECK (proposed_rent_amount > 0),
    CONSTRAINT chk_proposal_deposit CHECK (proposed_deposit_amount >= 0),
    CONSTRAINT chk_proposal_rent_due_day CHECK (proposed_rent_due_day >= 1 AND proposed_rent_due_day <= 31)
);

CREATE INDEX IF NOT EXISTS idx_rental_proposals_enquiry_id ON rental_proposals (enquiry_id);
CREATE INDEX IF NOT EXISTS idx_rental_proposals_conversation_id ON rental_proposals (conversation_id);
CREATE INDEX IF NOT EXISTS idx_rental_proposals_property_id ON rental_proposals (property_id);
CREATE INDEX IF NOT EXISTS idx_rental_proposals_unit_id ON rental_proposals (unit_id);
CREATE INDEX IF NOT EXISTS idx_rental_proposals_prospective_renter_id ON rental_proposals (prospective_renter_id);
CREATE INDEX IF NOT EXISTS idx_rental_proposals_landlord_user_id ON rental_proposals (landlord_user_id);
CREATE INDEX IF NOT EXISTS idx_rental_proposals_status ON rental_proposals (status);
CREATE INDEX IF NOT EXISTS idx_rental_proposals_expires_at ON rental_proposals (expires_at);
CREATE INDEX IF NOT EXISTS idx_rental_proposals_created_at ON rental_proposals (created_at DESC);

CREATE TABLE IF NOT EXISTS rental_proposal_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proposal_id UUID NOT NULL REFERENCES rental_proposals(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    proposed_rent_amount DECIMAL(12, 2) NOT NULL,
    proposed_deposit_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    proposed_start_date DATE NOT NULL,
    proposed_end_date DATE,
    proposed_rent_due_day INTEGER NOT NULL DEFAULT 1,
    special_conditions TEXT,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (proposal_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_rental_proposal_versions_proposal_id ON rental_proposal_versions (proposal_id);

CREATE TABLE IF NOT EXISTS rental_proposal_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proposal_id UUID NOT NULL REFERENCES rental_proposals(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    previous_status rental_proposal_status,
    new_status rental_proposal_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rental_proposal_status_history_proposal_id ON rental_proposal_status_history (proposal_id);
CREATE INDEX IF NOT EXISTS idx_rental_proposal_status_history_created_at ON rental_proposal_status_history (created_at DESC);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_rental_proposals_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_rental_proposals_updated_at ON rental_proposals;
CREATE TRIGGER trigger_update_rental_proposals_updated_at
    BEFORE UPDATE ON rental_proposals
    FOR EACH ROW
    EXECUTE FUNCTION update_rental_proposals_updated_at();

-- Trigger for rental proposal status history
CREATE OR REPLACE FUNCTION record_rental_proposal_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO rental_proposal_status_history (proposal_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_rental_proposal_status_history ON rental_proposals;
CREATE TRIGGER trigger_record_rental_proposal_status_history
    BEFORE UPDATE ON rental_proposals
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_rental_proposal_status_history();
