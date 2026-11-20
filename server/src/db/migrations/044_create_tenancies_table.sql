-- Migration: 044_create_tenancies_table
-- Description: Create tenancies table for rental agreements

CREATE TYPE tenancy_status AS ENUM ('draft', 'pending_approval', 'active', 'terminated', 'expired', 'cancelled', 'disputed');

CREATE TABLE IF NOT EXISTS tenancies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
    -- Tenancy details
    tenancy_type VARCHAR(50) NOT NULL DEFAULT 'residential', -- 'residential', 'commercial', 'short_term'
    status tenancy_status NOT NULL DEFAULT 'draft',
    -- Dates
    start_date DATE NOT NULL,
    end_date DATE,
    notice_period_days INTEGER NOT NULL DEFAULT 30,
    -- Financial
    rent_amount DECIMAL(12, 2) NOT NULL,
    deposit_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    deposit_paid BOOLEAN NOT NULL DEFAULT FALSE,
    deposit_held_by VARCHAR(50), -- 'landlord', 'agency', 'scheme'
    deposit_scheme_reference VARCHAR(100),
    rent_due_day INTEGER NOT NULL DEFAULT 1, -- Day of month
    payment_method VARCHAR(50),
    payment_reference VARCHAR(100),
    -- Terms
    terms_document_url VARCHAR(500),
    terms_accepted_at TIMESTAMPTZ,
    special_conditions TEXT,
    -- Management
    managed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    managed_by_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    -- Termination
    terminated_at TIMESTAMPTZ,
    terminated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    termination_reason TEXT,
    termination_notice_date DATE,
    -- Metadata
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_dates CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_rent_positive CHECK (rent_amount > 0)
);

CREATE INDEX IF NOT EXISTS idx_tenancies_property_id ON tenancies (property_id);
CREATE INDEX IF NOT EXISTS idx_tenancies_unit_id ON tenancies (unit_id);
CREATE INDEX IF NOT EXISTS idx_tenancies_status ON tenancies (status);
CREATE INDEX IF NOT EXISTS idx_tenancies_dates ON tenancies (start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_tenancies_managed_by_user ON tenancies (managed_by_user_id) WHERE managed_by_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tenancies_managed_by_org ON tenancies (managed_by_organisation_id) WHERE managed_by_organisation_id IS NOT NULL;

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_tenancies_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_tenancies_updated_at ON tenancies;
CREATE TRIGGER trigger_update_tenancies_updated_at
    BEFORE UPDATE ON tenancies
    FOR EACH ROW
    EXECUTE FUNCTION update_tenancies_updated_at();

-- Tenancy history table (audit)
CREATE TABLE IF NOT EXISTS tenancy_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'created', 'approved', 'activated', 'terminated', 'expired', 'cancelled', 'updated'
    previous_status tenancy_status,
    previous_rent_amount DECIMAL(12, 2),
    previous_end_date DATE,
    previous_managed_by_user_id UUID,
    previous_managed_by_organisation_id UUID,
    new_status tenancy_status,
    new_rent_amount DECIMAL(12, 2),
    new_end_date DATE,
    new_managed_by_user_id UUID,
    new_managed_by_organisation_id UUID,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tenancy_history_tenancy_id ON tenancy_history (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_tenancy_history_created_at ON tenancy_history (created_at DESC);