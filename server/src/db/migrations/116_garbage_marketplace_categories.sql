-- Migration: 116_garbage_marketplace_categories
-- Description: Task 13.7 — seed the 'garbage' service_domain with independently
--   selectable marketplace categories and capabilities so customers can raise
--   garbage collection requests through the unified 13.5 marketplace and
--   providers can publish offerings that the 13.7 operations engine consumes.
--   The 'garbage' domain already exists in the service_domain enum (original
--   domains). Additive and idempotent: safe on fresh and populated databases.

INSERT INTO service_categories (id, domain, name, description, sort_order) VALUES
  ('garbage_household',   'garbage', 'Household garbage collection',   'Routine household waste collection', 400),
  ('garbage_recycling',   'garbage', 'Recycling collection',           'Sorted recyclables collection', 410),
  ('garbage_bulky',       'garbage', 'Bulky waste pickup',             'Furniture and bulky item removal', 420),
  ('garbage_organic',     'garbage', 'Organic / green waste',          'Garden and organic waste collection', 430),
  ('garbage_commercial',  'garbage', 'Commercial waste collection',    'Business and commercial waste', 440)
ON CONFLICT (id) DO NOTHING;

INSERT INTO service_capabilities (id, domain, name, description, sort_order) VALUES
  ('gw_recurring',     'garbage', 'Recurring schedule',   'Weekly/biweekly/monthly plan', 10),
  ('gw_one_time',      'garbage', 'One-time pickup',      'Single collection', 20),
  ('gw_recycling',     'garbage', 'Recycling handling',   'Sorted recycling handling', 30),
  ('gw_bulky',         'garbage', 'Bulky item removal',   'Bulky item removal', 40),
  ('gw_bin_supply',    'garbage', 'Bin provision',        'Provider supplies bins', 50),
  ('gw_verified',      'garbage', 'Verified provider',    'Verified/registered hauler', 60)
ON CONFLICT (id) DO NOTHING;