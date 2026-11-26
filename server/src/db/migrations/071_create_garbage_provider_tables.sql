-- Migration: 071_create_garbage_provider_tables
-- Description: Create garbage_providers and garbage_provider_assignments tables

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'garbage_assignment_type') THEN
        CREATE TYPE garbage_assignment_type AS ENUM ('scheduled', 'on_demand');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'garbage_provider_status') THEN
        CREATE TYPE garbage_provider_status AS ENUM ('active', 'inactive', 'suspended', 'terminated');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'collection_frequency') THEN
        CREATE TYPE collection_frequency AS ENUM ('daily', 'weekly', 'biweekly', 'monthly', 'on_call');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS garbage_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    contact_phone VARCHAR(50) NOT NULL,
    contact_email VARCHAR(254),
    address TEXT,
    service_areas JSONB NOT NULL DEFAULT '[]',
    status garbage_provider_status NOT NULL DEFAULT 'active',
    rating DECIMAL(3, 2),
    total_collections INTEGER NOT NULL DEFAULT 0,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_garbage_rating CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5))
);

CREATE INDEX IF NOT EXISTS idx_garbage_providers_organisation_id ON garbage_providers (organisation_id);
CREATE INDEX IF NOT EXISTS idx_garbage_providers_status ON garbage_providers (status);
CREATE INDEX IF NOT EXISTS idx_garbage_providers_contact_phone ON garbage_providers (contact_phone);

CREATE TABLE IF NOT EXISTS garbage_provider_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    garbage_provider_id UUID NOT NULL REFERENCES garbage_providers(id) ON DELETE CASCADE,
    assignment_type garbage_assignment_type NOT NULL DEFAULT 'scheduled',
    frequency collection_frequency NOT NULL DEFAULT 'weekly',
    day_of_week INTEGER,
    time_slot VARCHAR(50),
    status garbage_provider_status NOT NULL DEFAULT 'active',
    assigned_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    effective_from DATE NOT NULL,
    effective_to DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_assignment_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_garbage_assignments_property_id ON garbage_provider_assignments (property_id);
CREATE INDEX IF NOT EXISTS idx_garbage_assignments_unit_id ON garbage_provider_assignments (unit_id);
CREATE INDEX IF NOT EXISTS idx_garbage_assignments_provider_id ON garbage_provider_assignments (garbage_provider_id);
CREATE INDEX IF NOT EXISTS idx_garbage_assignments_status ON garbage_provider_assignments (status);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_garbage_provider_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_garbage_provider_assignments_updated_at ON garbage_provider_assignments;
CREATE TRIGGER trigger_update_garbage_provider_assignments_updated_at
    BEFORE UPDATE ON garbage_provider_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_garbage_provider_assignments_updated_at();
