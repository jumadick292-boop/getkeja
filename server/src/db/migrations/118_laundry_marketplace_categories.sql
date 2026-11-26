-- Migration: 118_laundry_marketplace_categories
-- Description: Task 13.8 — seed the 'laundry' service_domain with independently
--   selectable marketplace categories and capabilities so customers can raise
--   laundry requests through the unified 13.5 marketplace and providers can
--   publish offerings the 13.8 operations engine consumes. The 'laundry' domain
--   already exists in the service_domain enum. Additive and idempotent.

INSERT INTO service_categories (id, domain, name, description, sort_order) VALUES
  ('laundry_wash_fold',   'laundry', 'Wash & Fold',          'Everyday washing, drying and folding', 500),
  ('laundry_dry_clean',   'laundry', 'Dry Cleaning',         'Professional dry cleaning', 510),
  ('laundry_iron_only',   'laundry', 'Ironing & Pressing',   'Ironing and pressing only', 520),
  ('laundry_bedding',     'laundry', 'Bedding & Linen',      'Bedding and household linen cleaning', 530),
  ('laundry_textile',     'laundry', 'Household Textiles',   'Curtains, rugs and household textiles', 540)
ON CONFLICT (id) DO NOTHING;

INSERT INTO service_capabilities (id, domain, name, description, sort_order) VALUES
  ('lw_pickup',         'laundry', 'Pickup & delivery', 'Door-to-door pickup and return', 10),
  ('lw_express',        'laundry', 'Express service',   'Expedited turnaround', 20),
  ('lw_eco',            'laundry', 'Eco-friendly',      'Eco-friendly detergents', 30),
  ('lw_delicate',       'laundry', 'Delicate handling', 'Delicate/special-care handling', 40),
  ('lw_stain',          'laundry', 'Stain treatment',   'Specialised stain treatment', 50),
  ('lw_per_kg',         'laundry', 'Per-kilogram pricing', 'Charged by weight', 60)
ON CONFLICT (id) DO NOTHING;