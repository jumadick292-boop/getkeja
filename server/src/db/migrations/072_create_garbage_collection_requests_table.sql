-- Migration: 072_create_garbage_collection_requests_table
-- Description: Create garbage_collection_requests and unit_occupancy_history tables

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'collection_request_status') THEN
        CREATE TYPE collection_request_status AS ENUM ('pending', 'assigned', 'in_progress', 'completed', 'cancelled');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'collection_request_type') THEN
        CREATE TYPE collection_request_type AS ENUM ('regular_collection', 'special_pickup', 'bulky_waste', 'recycling');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS garbage_collection_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    garbage_provider_id UUID REFERENCES garbage_providers(id) ON DELETE SET NULL,
    request_type collection_request_type NOT NULL DEFAULT 'regular_collection',
    status collection_request_status NOT NULL DEFAULT 'pending',
    scheduled_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_garbage_requests_property_id ON garbage_collection_requests (property_id);
CREATE INDEX IF NOT EXISTS idx_garbage_requests_unit_id ON garbage_collection_requests (unit_id);
CREATE INDEX IF NOT EXISTS idx_garbage_requests_provider_id ON garbage_collection_requests (garbage_provider_id);
CREATE INDEX IF NOT EXISTS idx_garbage_requests_status ON garbage_collection_requests (status);
CREATE INDEX IF NOT EXISTS idx_garbage_requests_scheduled_at ON garbage_collection_requests (scheduled_at);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_garbage_collection_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_garbage_collection_requests_updated_at ON garbage_collection_requests;
CREATE TRIGGER trigger_update_garbage_collection_requests_updated_at
    BEFORE UPDATE ON garbage_collection_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_garbage_collection_requests_updated_at();

-- Unit occupancy history
CREATE TABLE IF NOT EXISTS unit_occupancy_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    occupied_from DATE NOT NULL,
    occupied_to DATE,
    status VARCHAR(30) NOT NULL DEFAULT 'occupied',
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_occupancy_dates CHECK (occupied_to IS NULL OR occupied_to >= occupied_from)
);

CREATE INDEX IF NOT EXISTS idx_unit_occupancy_history_unit_id ON unit_occupancy_history (unit_id);
CREATE INDEX IF NOT EXISTS idx_unit_occupancy_history_tenancy_id ON unit_occupancy_history (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_unit_occupancy_history_tenant_id ON unit_occupancy_history (tenant_id);
CREATE INDEX IF NOT EXISTS idx_unit_occupancy_history_dates ON unit_occupancy_history (occupied_from, occupied_to);
