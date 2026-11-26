-- Migration: 070_create_tenants_table
-- Description: Create tenants table for tenant profiles separate from tenancy participants

CREATE TYPE tenant_status AS ENUM ('active', 'inactive', 'archived', 'blacklisted');

CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(254),
    phone VARCHAR(50) NOT NULL,
    id_number VARCHAR(50),
    id_type VARCHAR(50), -- 'national_id', 'passport', 'alien_id'
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(50),
    employer_name VARCHAR(255),
    employer_contact VARCHAR(255),
    monthly_income DECIMAL(12, 2),
    previous_landlord_name VARCHAR(255),
    previous_landlord_contact VARCHAR(255),
    move_in_date DATE,
    move_out_date DATE,
    status tenant_status NOT NULL DEFAULT 'active',
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_tenant_dates CHECK (move_out_date IS NULL OR move_out_date >= move_in_date)
);

CREATE INDEX IF NOT EXISTS idx_tenants_user_id ON tenants (user_id);
CREATE INDEX IF NOT EXISTS idx_tenants_property_id ON tenants (property_id);
CREATE INDEX IF NOT EXISTS idx_tenants_unit_id ON tenants (unit_id);
CREATE INDEX IF NOT EXISTS idx_tenants_tenancy_id ON tenants (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants (status);
CREATE INDEX IF NOT EXISTS idx_tenants_phone ON tenants (phone);
CREATE INDEX IF NOT EXISTS idx_tenants_id_number ON tenants (id_number) WHERE id_number IS NOT NULL;

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_tenants_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_tenants_updated_at ON tenants;
CREATE TRIGGER trigger_update_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_tenants_updated_at();
