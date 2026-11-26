-- Migration: 084_add_pricing_frequency_to_listings
-- Description: Add pricing frequency column to property_listings so the
-- public detail experience can correctly label rent as monthly, weekly,
-- annual, or sale price instead of assuming monthly rent.

ALTER TABLE property_listings
  ADD COLUMN IF NOT EXISTS pricing_frequency VARCHAR(20) NOT NULL DEFAULT 'monthly'
    CHECK (pricing_frequency IN ('monthly', 'weekly', 'annual', 'sale'));

CREATE INDEX IF NOT EXISTS idx_property_listings_pricing_frequency
  ON property_listings (pricing_frequency);

-- Backfill existing rows: treat any listing with a rent_amount as monthly.
UPDATE property_listings
  SET pricing_frequency = 'monthly'
  WHERE pricing_frequency IS NULL;
