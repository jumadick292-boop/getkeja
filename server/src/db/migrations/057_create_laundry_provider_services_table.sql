-- Migration: 057_create_laundry_provider_services_table
-- Description: Create laundry_provider_services for laundry-specific service offerings
-- Per blueprint laundry provider requirement

CREATE TABLE IF NOT EXISTS laundry_provider_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_profile_id UUID NOT NULL REFERENCES provider_profile_extensions(id) ON DELETE CASCADE,

    -- Service offerings
    offers_washing BOOLEAN NOT NULL DEFAULT FALSE,
    offers_dry_cleaning BOOLEAN NOT NULL DEFAULT FALSE,
    offers_ironing BOOLEAN NOT NULL DEFAULT FALSE,
    offers_folding BOOLEAN NOT NULL DEFAULT FALSE,
    offers_bedding_cleaning BOOLEAN NOT NULL DEFAULT FALSE,
    offers_household_textile_cleaning BOOLEAN NOT NULL DEFAULT FALSE,
    offers_other_services BOOLEAN NOT NULL DEFAULT FALSE,
    other_services_description TEXT,

    -- Special handling
    special_handling_info TEXT,

    -- Collection and delivery
    offers_pickup BOOLEAN NOT NULL DEFAULT FALSE,
    offers_delivery BOOLEAN NOT NULL DEFAULT FALSE,
    customer_visit_required BOOLEAN NOT NULL DEFAULT FALSE,
    pickup_delivery_areas JSONB NOT NULL DEFAULT '[]',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_laundry_provider_services_provider_id ON laundry_provider_services (provider_profile_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_laundry_provider_services_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_laundry_provider_services_updated_at ON laundry_provider_services;
CREATE TRIGGER trigger_update_laundry_provider_services_updated_at
    BEFORE UPDATE ON laundry_provider_services
    FOR EACH ROW
    EXECUTE FUNCTION update_laundry_provider_services_updated_at();