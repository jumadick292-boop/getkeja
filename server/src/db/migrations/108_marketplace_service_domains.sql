-- Migration: 108_marketplace_service_domains
-- Description: Task 13.5 — extend the platform service_domain enum with the
--   additional home-services domains required by the unified service-request +
--   quotation marketplace (18 categories). This migration ONLY adds enum
--   values; the categories/capabilities that use them are seeded in 109 so the
--   new labels are never referenced inside the same transaction (PostgreSQL
--   forbids using a value added by ALTER TYPE ... ADD VALUE in the same txn).
--   Additive and idempotent: safe on fresh and populated databases.

ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'cleaning';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'plumbing';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'electrical';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'hvac';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'pest_control';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'landscaping';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'carpentry';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'painting';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'roofing';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'flooring';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'tiling';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'appliances';
ALTER TYPE service_domain ADD VALUE IF NOT EXISTS 'general';