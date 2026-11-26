-- Migration: 085_add_alert_frequency_to_saved_searches
-- Description: Add alert_frequency column to saved_searches and create
--              search_alert_deduplication table for tracking sent alerts.

-- ---------------------------------------------------------------------------
-- Add alert_frequency to saved_searches
-- ---------------------------------------------------------------------------
ALTER TABLE saved_searches
  ADD COLUMN IF NOT EXISTS alert_frequency VARCHAR(20) NOT NULL DEFAULT 'immediate';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_saved_searches_alert_frequency'
  ) THEN
    ALTER TABLE saved_searches
      ADD CONSTRAINT chk_saved_searches_alert_frequency
      CHECK (alert_frequency IN ('immediate', 'daily', 'weekly'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_saved_searches_alert_frequency ON saved_searches (alert_frequency);

-- ---------------------------------------------------------------------------
-- Search alert deduplication table
-- Tracks which listings have been alerted for which saved searches,
-- preventing duplicate notifications.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS search_alert_deduplication (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    saved_search_id UUID NOT NULL REFERENCES saved_searches(id) ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES property_listings(id) ON DELETE CASCADE,
    alert_sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (saved_search_id, listing_id)
);

CREATE INDEX IF NOT EXISTS idx_search_alert_dedup_user_id ON search_alert_deduplication (user_id);
CREATE INDEX IF NOT EXISTS idx_search_alert_dedup_search_id ON search_alert_deduplication (saved_search_id);
CREATE INDEX IF NOT EXISTS idx_search_alert_dedup_listing_id ON search_alert_deduplication (listing_id);
CREATE INDEX IF NOT EXISTS idx_search_alert_dedup_sent_at ON search_alert_deduplication (alert_sent_at DESC);

-- ---------------------------------------------------------------------------
-- Trigger to update saved_searches.updated_at
-- ---------------------------------------------------------------------------
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
