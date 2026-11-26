-- Migration: 080_create_lease_document_tables
-- Description: Create rental agreement and lease document tables

CREATE TYPE rental_agreement_status AS ENUM ('draft', 'pending_signature', 'active', 'renewed', 'terminated', 'expired', 'archived');
CREATE TYPE lease_document_type AS ENUM ('tenancy_agreement', 'lease_renewal', 'termination_notice', 'rent_receipt', 'inspection_report', 'maintenance_report', 'notice', 'correspondence', 'other');

CREATE TABLE IF NOT EXISTS rental_agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
    agreement_number VARCHAR(100) NOT NULL,
    status rental_agreement_status NOT NULL DEFAULT 'draft',
    start_date DATE NOT NULL,
    end_date DATE,
    monthly_rent DECIMAL(12, 2) NOT NULL,
    deposit_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    rent_due_day INTEGER NOT NULL DEFAULT 1,
    payment_method VARCHAR(50),
    special_conditions TEXT,
    document_url VARCHAR(500),
    signed_by_tenant_at TIMESTAMPTZ,
    signed_by_landlord_at TIMESTAMPTZ,
    renewed_from_agreement_id UUID REFERENCES rental_agreements(id) ON DELETE SET NULL,
    terminated_at TIMESTAMPTZ,
    termination_reason TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_agreement_dates CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_agreement_rent CHECK (monthly_rent > 0),
    CONSTRAINT chk_agreement_deposit CHECK (deposit_amount >= 0),
    CONSTRAINT chk_agreement_rent_due_day CHECK (rent_due_day >= 1 AND rent_due_day <= 31),
    UNIQUE (agreement_number)
);

CREATE INDEX IF NOT EXISTS idx_rental_agreements_tenancy_id ON rental_agreements (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_tenant_id ON rental_agreements (tenant_id);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_property_id ON rental_agreements (property_id);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_unit_id ON rental_agreements (unit_id);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_status ON rental_agreements (status);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_agreement_number ON rental_agreements (agreement_number);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_renewed_from ON rental_agreements (renewed_from_agreement_id);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_created_at ON rental_agreements (created_at DESC);

CREATE TABLE IF NOT EXISTS lease_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_agreement_id UUID REFERENCES rental_agreements(id) ON DELETE CASCADE,
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    type lease_document_type NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size_bytes BIGINT,
    mime_type VARCHAR(100),
    category VARCHAR(100),
    is_private BOOLEAN NOT NULL DEFAULT TRUE,
    version INTEGER NOT NULL DEFAULT 1,
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lease_documents_agreement_id ON lease_documents (rental_agreement_id);
CREATE INDEX IF NOT EXISTS idx_lease_documents_property_id ON lease_documents (property_id);
CREATE INDEX IF NOT EXISTS idx_lease_documents_unit_id ON lease_documents (unit_id);
CREATE INDEX IF NOT EXISTS idx_lease_documents_tenancy_id ON lease_documents (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_lease_documents_type ON lease_documents (type);
CREATE INDEX IF NOT EXISTS idx_lease_documents_uploaded_by ON lease_documents (uploaded_by);
CREATE INDEX IF NOT EXISTS idx_lease_documents_created_at ON lease_documents (created_at DESC);

CREATE TABLE IF NOT EXISTS document_access_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES lease_documents(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action VARCHAR(50) NOT NULL, -- 'view', 'download', 'upload', 'delete'
    accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address VARCHAR(45),
    user_agent TEXT
);

CREATE INDEX IF NOT EXISTS idx_document_access_events_document_id ON document_access_events (document_id);
CREATE INDEX IF NOT EXISTS idx_document_access_events_user_id ON document_access_events (user_id);
CREATE INDEX IF NOT EXISTS idx_document_access_events_accessed_at ON document_access_events (accessed_at DESC);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_rental_agreements_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_rental_agreements_updated_at ON rental_agreements;
CREATE TRIGGER trigger_update_rental_agreements_updated_at
    BEFORE UPDATE ON rental_agreements
    FOR EACH ROW
    EXECUTE FUNCTION update_rental_agreements_updated_at();

CREATE OR REPLACE FUNCTION update_lease_documents_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_lease_documents_updated_at ON lease_documents;
CREATE TRIGGER trigger_update_lease_documents_updated_at
    BEFORE UPDATE ON lease_documents
    FOR EACH ROW
    EXECUTE FUNCTION update_lease_documents_updated_at();

-- Lease renewal records
CREATE TABLE IF NOT EXISTS lease_renewal_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_agreement_id UUID NOT NULL REFERENCES rental_agreements(id) ON DELETE CASCADE,
    new_agreement_id UUID REFERENCES rental_agreements(id) ON DELETE SET NULL,
    renewal_notice_sent_at TIMESTAMPTZ,
    renewal_response_at TIMESTAMPTZ,
    renewal_decision VARCHAR(20), -- 'accepted', 'declined', 'negotiating'
    new_start_date DATE,
    new_end_date DATE,
    new_monthly_rent DECIMAL(12, 2),
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lease_renewal_records_agreement_id ON lease_renewal_records (rental_agreement_id);

-- Move-out inspections
CREATE TABLE IF NOT EXISTS move_out_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
    inspection_date DATE NOT NULL,
    inspector_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    overall_condition VARCHAR(50),
    meter_readings JSONB,
    key_returned BOOLEAN NOT NULL DEFAULT FALSE,
    damage_notes TEXT,
    cleaning_required BOOLEAN NOT NULL DEFAULT FALSE,
    cleaning_cost DECIMAL(12, 2),
    repair_cost DECIMAL(12, 2),
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_moveout_cleaning_cost CHECK (cleaning_cost IS NULL OR cleaning_cost >= 0),
    CONSTRAINT chk_moveout_repair_cost CHECK (repair_cost IS NULL OR repair_cost >= 0)
);

CREATE INDEX IF NOT EXISTS idx_move_out_inspections_tenancy_id ON move_out_inspections (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_move_out_inspections_unit_id ON move_out_inspections (unit_id);

-- Move-out inspection items
CREATE TABLE IF NOT EXISTS move_out_inspection_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inspection_id UUID NOT NULL REFERENCES move_out_inspections(id) ON DELETE CASCADE,
    item_category VARCHAR(100) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    condition_rating VARCHAR(30) NOT NULL,
    notes TEXT,
    photo_url VARCHAR(500),
    damage_cost DECIMAL(12, 2),
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_moveout_item_damage_cost CHECK (damage_cost IS NULL OR damage_cost >= 0)
);

CREATE INDEX IF NOT EXISTS idx_move_out_inspection_items_inspection_id ON move_out_inspection_items (inspection_id);

-- Lease termination records
CREATE TABLE IF NOT EXISTS lease_termination_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_agreement_id UUID NOT NULL REFERENCES rental_agreements(id) ON DELETE CASCADE,
    notice_period_days INTEGER,
    notice_given_at TIMESTAMPTZ,
    termination_date DATE,
    termination_reason TEXT,
    move_out_inspection_id UUID REFERENCES move_out_inspections(id) ON DELETE SET NULL,
    deposit_refund_amount DECIMAL(12, 2),
    deposit_refunded_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lease_termination_records_agreement_id ON lease_termination_records (rental_agreement_id);

-- Move-in inspections
CREATE TABLE IF NOT EXISTS move_in_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
    inspection_date DATE NOT NULL,
    inspector_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    overall_condition VARCHAR(50), -- 'excellent', 'good', 'fair', 'poor'
    meter_readings JSONB,
    key_handover BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_move_in_inspections_tenancy_id ON move_in_inspections (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_move_in_inspections_unit_id ON move_in_inspections (unit_id);

-- Inspection items
CREATE TABLE IF NOT EXISTS inspection_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inspection_id UUID NOT NULL REFERENCES move_in_inspections(id) ON DELETE CASCADE,
    item_category VARCHAR(100) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    condition_rating VARCHAR(30) NOT NULL, -- 'excellent', 'good', 'fair', 'poor', 'damaged', 'missing'
    notes TEXT,
    photo_url VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inspection_items_inspection_id ON inspection_items (inspection_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_move_in_inspections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_move_in_inspections_updated_at ON move_in_inspections;
CREATE TRIGGER trigger_update_move_in_inspections_updated_at
    BEFORE UPDATE ON move_in_inspections
    FOR EACH ROW
    EXECUTE FUNCTION update_move_in_inspections_updated_at();

CREATE OR REPLACE FUNCTION update_move_out_inspections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_move_out_inspections_updated_at ON move_out_inspections;
CREATE TRIGGER trigger_update_move_out_inspections_updated_at
    BEFORE UPDATE ON move_out_inspections
    FOR EACH ROW
    EXECUTE FUNCTION update_move_out_inspections_updated_at();
