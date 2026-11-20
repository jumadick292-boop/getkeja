-- Migration: 059_create_provider_service_areas_table
-- Description: Create provider_service_areas for reusable service area model
-- Per blueprint Section 6 (Service Areas)

CREATE TABLE IF NOT EXISTS provider_service_areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    specialized_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE CASCADE,

    -- Geographic coverage
    country VARCHAR(100),
    county VARCHAR(100),
    city VARCHAR(100),
    neighbourhood VARCHAR(100),
    area_description TEXT,

    -- Coordinates or boundaries
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    radius_km DECIMAL(8, 2),

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_provider_service_areas_profile_id ON provider_service_areas (specialized_profile_id);
CREATE INDEX IF NOT EXISTS idx_provider_service_areas_location ON provider_service_areas (country, county, city);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_provider_service_areas_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_provider_service_areas_updated_at ON provider_service_areas;
CREATE TRIGGER trigger_update_provider_service_areas_updated_at
    BEFORE UPDATE ON provider_service_areas
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_service_areas_updated_at();