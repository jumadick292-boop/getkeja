-- Migration: 112_mandatory_marketplace_categories
-- Description: Task 13.5 (mandatory categories) — seed four independently
--   selectable categories and their capabilities:
--     1. Wi-Fi Installation & Configuration   (networking)
--     2. Internet Installation & Connectivity  (networking)  -- NOT merged with Wi-Fi
--     3. Solar Installation & Maintenance      (solar)
--     4. Painting & Decoration                 (painting)
--   Wi-Fi and Internet share network capabilities but remain separate
--   categories so customers can search/request either independently. Uses the
--   enum values added in 111 (separate transaction). Additive and idempotent.

INSERT INTO service_categories (id, domain, name, description, sort_order) VALUES
  ('wifi_installation',      'networking', 'Wi-Fi Installation & Configuration',   'Home/office Wi-Fi setup, mesh, coverage and troubleshooting', 300),
  ('internet_installation',  'networking', 'Internet Installation & Connectivity', 'Broadband/fibre connectivity installation and troubleshooting', 310),
  ('solar_installation',     'solar',      'Solar Installation & Maintenance',      'Solar power new installation, assessment and maintenance', 320),
  ('painting_decoration',    'painting',   'Painting & Decoration',                 'Interior/exterior painting, wallpaper and decorative finishes', 330)
ON CONFLICT DO NOTHING;

-- Shared networking capabilities (used by BOTH Wi-Fi and Internet offerings).
INSERT INTO service_capabilities (id, domain, name, description, sort_order) VALUES
  ('net_residential',      'networking', 'Residential installation', 'Home/residential setup', 10),
  ('net_commercial',       'networking', 'Commercial installation',  'Business/commercial setup', 20),
  ('net_new_install',      'networking', 'New installation',         'New network installation', 30),
  ('net_troubleshooting',  'networking', 'Troubleshooting',          'Diagnose and fix issues', 40),
  ('net_router_setup',     'networking', 'Router/equipment setup',   'Router and equipment configuration', 50),
  ('net_mesh',             'networking', 'Mesh/coverage extension',  'Mesh and coverage extension', 60),
  ('net_coverage_survey',  'networking', 'Coverage survey',          'Site coverage assessment', 70)
ON CONFLICT DO NOTHING;

-- Solar capabilities.
INSERT INTO service_capabilities (id, domain, name, description, sort_order) VALUES
  ('solar_new_install',      'solar', 'New installation',     'New solar power installation', 10),
  ('solar_maintenance',      'solar', 'Maintenance',          'Solar system maintenance', 20),
  ('solar_site_assessment',  'solar', 'Site assessment',      'On-site solar assessment', 30),
  ('solar_inverter',         'solar', 'Inverter service',     'Inverter install/service', 40),
  ('solar_battery',          'solar', 'Battery service',      'Battery install/service', 50),
  ('solar_panels',           'solar', 'Panel service',        'Panel install/service', 60)
ON CONFLICT DO NOTHING;

-- Painting & decoration capabilities (separate, selectable).
INSERT INTO service_capabilities (id, domain, name, description, sort_order) VALUES
  ('paint_interior',      'painting', 'Interior painting',      'Interior painting', 10),
  ('paint_exterior',      'painting', 'Exterior painting',      'Exterior painting', 20),
  ('paint_decorative',    'painting', 'Decorative finishes',    'Decorative finishes', 30),
  ('paint_wallpaper',     'painting', 'Wallpaper installation', 'Wallpaper installation', 40),
  ('paint_surface_prep',  'painting', 'Surface preparation',    'Surface preparation', 50)
ON CONFLICT DO NOTHING;