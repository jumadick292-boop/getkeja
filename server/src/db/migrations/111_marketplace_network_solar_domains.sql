-- Migration: 111_marketplace_network_solar_domains
-- Description: Task 13.5 (mandatory categories) — extend service_domain with
--   'networking' (Wi-Fi + Internet, kept as SEPARATE categories) and 'solar'
--   (Solar Installation & Maintenance). Enum-only change; the categories and
--   capabilities that use these values are seeded in 112 so the new labels are
--   never referenced in the same transaction. Additive and idempotent.

ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'networking';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'solar';