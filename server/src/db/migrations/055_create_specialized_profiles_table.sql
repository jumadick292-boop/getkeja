-- Migration: 055_create_specialized_profiles_table
-- Description: Create specialized_profiles table for stakeholder-specific profile extensions
-- Per blueprint Section 11.1.2 and stakeholder definitions in Section 7

CREATE TYPE profile_category AS ENUM (
    'house_seeker',
    'tenant',
    'landlord',
    'real_estate_agent',
    'agency',
    'property_manager',
    'caretaker',
    'moving_service_provider',
    'garbage_collection_provider',
    'laundry_service_provider'
);

CREATE TYPE profile_verification_status AS ENUM (
    'draft',
    'incomplete',
    'submitted',
    'pending_review',
    'approved',
    'rejected',
    'suspended'
);

CREATE TABLE IF NOT EXISTS specialized_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_category profile_category NOT NULL,
    user_profile_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,

    -- Common identity fields
    full_name VARCHAR(200),
    display_name VARCHAR(100),
    profile_photo_url VARCHAR(500),
    business_name VARCHAR(200),
    business_logo_url VARCHAR(500),
    description TEXT,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    website_url VARCHAR(500),

    -- Verification and status
    verification_status profile_verification_status NOT NULL DEFAULT 'draft',
    submitted_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    rejection_reason TEXT,
    completion_percentage INTEGER NOT NULL DEFAULT 0,
    missing_fields JSONB NOT NULL DEFAULT '[]',

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_specialized_profiles_user_id ON specialized_profiles (user_id);
CREATE INDEX IF NOT EXISTS idx_specialized_profiles_category ON specialized_profiles (profile_category);
CREATE INDEX IF NOT EXISTS idx_specialized_profiles_verification_status ON specialized_profiles (verification_status);
CREATE INDEX IF NOT EXISTS idx_specialized_profiles_organisation_id ON specialized_profiles (organisation_id);
CREATE INDEX IF NOT EXISTS idx_specialized_profiles_user_category ON specialized_profiles (user_id, profile_category);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_specialized_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_specialized_profiles_updated_at ON specialized_profiles;
CREATE TRIGGER trigger_update_specialized_profiles_updated_at
    BEFORE UPDATE ON specialized_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_specialized_profiles_updated_at();