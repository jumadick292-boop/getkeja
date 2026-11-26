-- Migration: 086_create_house_seeker_comparison_tables
-- Description: Create tables for house seeker property comparison lists.

-- ---------------------------------------------------------------------------
-- Comparison lists (one per user)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS house_seeker_comparison_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_house_seeker_comparison_lists_user_id
    ON house_seeker_comparison_lists (user_id);

CREATE OR REPLACE FUNCTION update_house_seeker_comparison_lists_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_house_seeker_comparison_lists_updated_at
    ON house_seeker_comparison_lists;
CREATE TRIGGER trigger_update_house_seeker_comparison_lists_updated_at
    BEFORE UPDATE ON house_seeker_comparison_lists
    FOR EACH ROW
    EXECUTE FUNCTION update_house_seeker_comparison_lists_updated_at();

-- ---------------------------------------------------------------------------
-- Comparison items (listings in a user's comparison list)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS house_seeker_comparison_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID NOT NULL REFERENCES house_seeker_comparison_lists(id) ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES property_listings(id) ON DELETE CASCADE,
    position INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_comparison_items_list_listing UNIQUE (list_id, listing_id)
);

CREATE INDEX IF NOT EXISTS idx_house_seeker_comparison_items_list_id
    ON house_seeker_comparison_items (list_id);
CREATE INDEX IF NOT EXISTS idx_house_seeker_comparison_items_listing_id
    ON house_seeker_comparison_items (listing_id);
CREATE INDEX IF NOT EXISTS idx_house_seeker_comparison_items_position
    ON house_seeker_comparison_items (list_id, position);
