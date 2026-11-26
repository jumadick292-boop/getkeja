-- Migration: 069_create_property_listings_table
-- Description: Create property_listings table for published property marketing listings

CREATE TYPE listing_status AS ENUM ('draft', 'published', 'paused', 'withdrawn', 'archived');

CREATE TABLE IF NOT EXISTS property_listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status listing_status NOT NULL DEFAULT 'draft',
    rent_amount DECIMAL(12, 2),
    deposit_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    available_from DATE,
    available_to DATE,
    furnished BOOLEAN NOT NULL DEFAULT FALSE,
    pet_policy VARCHAR(50), -- 'allowed', 'not_allowed', 'negotiable'
    smoking_allowed BOOLEAN NOT NULL DEFAULT FALSE,
    features JSONB,
    amenities JSONB,
    images JSONB,
    floor_plan_url VARCHAR(500),
    virtual_tour_url VARCHAR(500),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    published_at TIMESTAMPTZ,
    paused_at TIMESTAMPTZ,
    withdrawn_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_listing_dates CHECK (available_to IS NULL OR available_to >= available_from),
    CONSTRAINT chk_listing_rent CHECK (rent_amount IS NULL OR rent_amount > 0)
);

CREATE INDEX IF NOT EXISTS idx_property_listings_property_id ON property_listings (property_id);
CREATE INDEX IF NOT EXISTS idx_property_listings_unit_id ON property_listings (unit_id);
CREATE INDEX IF NOT EXISTS idx_property_listings_status ON property_listings (status);
CREATE INDEX IF NOT EXISTS idx_property_listings_created_by ON property_listings (created_by);
CREATE INDEX IF NOT EXISTS idx_property_listings_available_from ON property_listings (available_from);
CREATE INDEX IF NOT EXISTS idx_property_listings_rent_amount ON property_listings (rent_amount);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_property_listings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_property_listings_updated_at ON property_listings;
CREATE TRIGGER trigger_update_property_listings_updated_at
    BEFORE UPDATE ON property_listings
    FOR EACH ROW
    EXECUTE FUNCTION update_property_listings_updated_at();

-- Listing status history (audit)
CREATE TABLE IF NOT EXISTS listing_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES property_listings(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    previous_status listing_status,
    new_status listing_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_listing_status_history_listing_id ON listing_status_history (listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_status_history_created_at ON listing_status_history (created_at DESC);

-- Trigger for listing status history
CREATE OR REPLACE FUNCTION record_listing_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO listing_status_history (listing_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_listing_status_history ON property_listings;
CREATE TRIGGER trigger_record_listing_status_history
    BEFORE UPDATE ON property_listings
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_listing_status_history();
