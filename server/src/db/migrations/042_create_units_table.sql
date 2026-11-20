-- Migration: 042_create_units_table
-- Description: Create units table for individual rental units within properties

CREATE TABLE IF NOT EXISTS units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_number VARCHAR(50) NOT NULL,
    unit_type VARCHAR(50) NOT NULL, -- 'bedsitter', '1_bedroom', '2_bedroom', '3_bedroom', 'commercial', 'parking', 'storage', 'other'
    floor_number INTEGER,
    bedrooms INTEGER NOT NULL DEFAULT 0,
    bathrooms DECIMAL(3, 1) NOT NULL DEFAULT 1.0,
    area_sqm DECIMAL(8, 2),
    rent_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    deposit_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'vacant', -- 'vacant', 'occupied', 'reserved', 'under_maintenance', 'unavailable'
    description TEXT,
    amenities JSONB,
    features JSONB,
    images JSONB,
    -- Utility metering
    has_separate_meter BOOLEAN NOT NULL DEFAULT FALSE,
    meter_number VARCHAR(100),
    -- Created/updated
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (property_id, unit_number)
);

CREATE INDEX IF NOT EXISTS idx_units_property_id ON units (property_id);
CREATE INDEX IF NOT EXISTS idx_units_status ON units (status);
CREATE INDEX IF NOT EXISTS idx_units_unit_type ON units (unit_type);
CREATE INDEX IF NOT EXISTS idx_units_rent_amount ON units (rent_amount);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_units_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_units_updated_at ON units;
CREATE TRIGGER trigger_update_units_updated_at
    BEFORE UPDATE ON units
    FOR EACH ROW
    EXECUTE FUNCTION update_units_updated_at();