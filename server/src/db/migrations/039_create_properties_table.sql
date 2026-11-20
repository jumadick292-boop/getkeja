-- Migration: 039_create_properties_table
-- Description: Create properties table for property listings and management

CREATE TABLE IF NOT EXISTS properties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    property_type VARCHAR(50) NOT NULL, -- 'apartment', 'house', 'commercial', 'land', 'hostel', 'other'
    status VARCHAR(30) NOT NULL DEFAULT 'draft', -- 'draft', 'published', 'archived', 'rented', 'under_maintenance'
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    county VARCHAR(100) NOT NULL,
    country CHAR(2) NOT NULL DEFAULT 'KE',
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    total_units INTEGER NOT NULL DEFAULT 0,
    amenities JSONB,
    features JSONB,
    images JSONB,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    published_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_properties_organisation_id ON properties (organisation_id);
CREATE INDEX IF NOT EXISTS idx_properties_status ON properties (status);
CREATE INDEX IF NOT EXISTS idx_properties_city_county ON properties (city, county);
CREATE INDEX IF NOT EXISTS idx_properties_created_by ON properties (created_by);
CREATE INDEX IF NOT EXISTS idx_properties_property_type ON properties (property_type);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_properties_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_properties_updated_at ON properties;
CREATE TRIGGER trigger_update_properties_updated_at
    BEFORE UPDATE ON properties
    FOR EACH ROW
    EXECUTE FUNCTION update_properties_updated_at();