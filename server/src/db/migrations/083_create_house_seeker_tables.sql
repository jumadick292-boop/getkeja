-- Migration: 083_create_house_seeker_tables
-- Description: Create tables for the House Seeker experience: discovery preferences,
--              saved homes, saved searches, and listing reports.

-- ---------------------------------------------------------------------------
-- House seeker discovery preferences (one row per user)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS house_seeker_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    min_budget DECIMAL(12, 2),
    max_budget DECIMAL(12, 2),
    preferred_property_types JSONB NOT NULL DEFAULT '[]'::jsonb,
    preferred_bedrooms INT,
    preferred_bathrooms INT,
    preferred_amenities JSONB NOT NULL DEFAULT '[]'::jsonb,
    preferred_locations JSONB NOT NULL DEFAULT '[]'::jsonb,
    move_in_date DATE,
    alerts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_hsp_budget CHECK (max_budget IS NULL OR min_budget IS NULL OR max_budget >= min_budget)
);

CREATE INDEX IF NOT EXISTS idx_house_seeker_preferences_user_id ON house_seeker_preferences (user_id);

CREATE OR REPLACE FUNCTION update_house_seeker_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_house_seeker_preferences_updated_at ON house_seeker_preferences;
CREATE TRIGGER trigger_update_house_seeker_preferences_updated_at
    BEFORE UPDATE ON house_seeker_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_house_seeker_preferences_updated_at();

-- ---------------------------------------------------------------------------
-- Saved homes / favourites
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS saved_listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES property_listings(id) ON DELETE CASCADE,
    collection VARCHAR(120),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_saved_listings_user_listing UNIQUE (user_id, listing_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_listings_user_id ON saved_listings (user_id);
CREATE INDEX IF NOT EXISTS idx_saved_listings_listing_id ON saved_listings (listing_id);

-- ---------------------------------------------------------------------------
-- Saved searches (for alerts and re-running)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS saved_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(160) NOT NULL,
    criteria JSONB NOT NULL DEFAULT '{}'::jsonb,
    alerts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_run_at TIMESTAMPTZ,
    last_alerted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_searches_user_id ON saved_searches (user_id);

CREATE OR REPLACE FUNCTION update_saved_searches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_saved_searches_updated_at ON saved_searches;
CREATE TRIGGER trigger_update_saved_searches_updated_at
    BEFORE UPDATE ON saved_searches
    FOR EACH ROW
    EXECUTE FUNCTION update_saved_searches_updated_at();

-- ---------------------------------------------------------------------------
-- Listing reports (house seeker -> moderation)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS listing_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES property_listings(id) ON DELETE CASCADE,
    reporter_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    reason VARCHAR(50) NOT NULL,
    details TEXT,
    evidence_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_listing_report_status CHECK (status IN ('pending', 'under_review', 'actioned', 'dismissed')),
    CONSTRAINT chk_listing_report_reason CHECK (reason IN ('suspicious', 'incorrect_info', 'misleading_photos', 'unavailable', 'fraud', 'inappropriate', 'other'))
);

CREATE INDEX IF NOT EXISTS idx_listing_reports_listing_id ON listing_reports (listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_reports_status ON listing_reports (status);
CREATE INDEX IF NOT EXISTS idx_listing_reports_reporter ON listing_reports (reporter_user_id);
CREATE INDEX IF NOT EXISTS idx_listing_reports_created_at ON listing_reports (created_at DESC);

CREATE OR REPLACE FUNCTION update_listing_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_listing_reports_updated_at ON listing_reports;
CREATE TRIGGER trigger_update_listing_reports_updated_at
    BEFORE UPDATE ON listing_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_listing_reports_updated_at();