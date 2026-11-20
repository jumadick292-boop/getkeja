-- Migration: 056_create_provider_profile_extensions_table
-- Description: Create provider_profile_extensions for moving, garbage, laundry providers
-- Per blueprint Section 7.2.7, 7.2.8, and laundry provider requirement

CREATE TABLE IF NOT EXISTS provider_profile_extensions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    specialized_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE CASCADE,

    -- Service information
    service_types JSONB NOT NULL DEFAULT '[]',
    service_description TEXT,
    operating_status VARCHAR(30) NOT NULL DEFAULT 'active',

    -- Business information
    registration_number VARCHAR(100),
    tax_id VARCHAR(100),
    business_hours JSONB,

    -- Availability
    available_24_7 BOOLEAN NOT NULL DEFAULT FALSE,
    emergency_service BOOLEAN NOT NULL DEFAULT FALSE,

    -- Insurance and certifications
    insurance_info JSONB,
    certifications JSONB,

    -- Contact
    booking_contact_email VARCHAR(255),
    booking_contact_phone VARCHAR(20),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_provider_profile_extensions_profile_id ON provider_profile_extensions (specialized_profile_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_provider_profile_extensions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_provider_profile_extensions_updated_at ON provider_profile_extensions;
CREATE TRIGGER trigger_update_provider_profile_extensions_updated_at
    BEFORE UPDATE ON provider_profile_extensions
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_profile_extensions_updated_at();