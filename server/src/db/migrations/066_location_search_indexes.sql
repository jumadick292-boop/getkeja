-- Add covering coordinate indexes for bounded radius and map viewport searches.
-- These preserve the existing DECIMAL coordinate model and require no PostGIS install.
CREATE INDEX IF NOT EXISTS idx_properties_published_coordinates
  ON properties (latitude, longitude, published_at DESC)
  WHERE status = 'published' AND latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_properties_published_locality
  ON properties (county, city, published_at DESC)
  WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_saved_locations_user_type_updated
  ON saved_locations (user_id, location_type, updated_at DESC);
