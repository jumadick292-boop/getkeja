-- Migration: 058_create_saved_locations_table
-- Description: Create saved_locations for reusable location records
-- Per blueprint Section 5 (Google Maps location pinning)

CREATE TYPE location_source AS ENUM (
    'device_gps',
    'manual_map_pin',
    'address_search',
    'text_entry'
);

CREATE TYPE location_type AS ENUM (
    'personal_residential',
    'business_office',
    'provider_operating',
    'service_area',
    'property_location'
);

CREATE TABLE IF NOT EXISTS saved_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    specialized_profile_id UUID REFERENCES specialized_profiles(id) ON DELETE CASCADE,

    -- Location type
    location_type location_type NOT NULL,
    label VARCHAR(100),

    -- Coordinates
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,

    -- Address information
    formatted_address TEXT,
    place_id VARCHAR(255),
    country VARCHAR(100),
    county VARCHAR(100),
    city VARCHAR(100),
    neighbourhood VARCHAR(100),
    street VARCHAR(200),
    building_name VARCHAR(200),

    -- Metadata
    location_source location_source NOT NULL,
    accuracy_meters DECIMAL(10, 2),
    is_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    confirmed_at TIMESTAMPTZ,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_locations_user_id ON saved_locations (user_id);
CREATE INDEX IF NOT EXISTS idx_saved_locations_profile_id ON saved_locations (specialized_profile_id);
CREATE INDEX IF NOT EXISTS idx_saved_locations_type ON saved_locations (location_type);
CREATE INDEX IF NOT EXISTS idx_saved_locations_coords ON saved_locations (latitude, longitude);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_saved_locations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_saved_locations_updated_at ON saved_locations;
CREATE TRIGGER trigger_update_saved_locations_updated_at
    BEFORE UPDATE ON saved_locations
    FOR EACH ROW
    EXECUTE FUNCTION update_saved_locations_updated_at();