-- Migration: 107_provider_service_catalogue
-- Description: Provider service-catalogue foundation (Task 13.4).
--   Adds platform-defined reference data (service categories + capabilities),
--   provider service offerings with lifecycle, per-offering capabilities and
--   pricing, offering-scoped service areas, business-location extensions on
--   saved_locations, provider operating hours and availability exceptions.
--   Additive and idempotent: safe on fresh and populated databases. No existing
--   provider/location/request records are dropped or rewritten destructively.

-- ---------------------------------------------------------------------------
-- Enums (guarded so re-runs are safe)
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE service_domain AS ENUM ('moving', 'garbage', 'laundry');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE provider_offering_status AS ENUM ('draft', 'active', 'paused', 'unavailable', 'archived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE pricing_model AS ENUM (
    'fixed', 'starting', 'per_item', 'per_unit', 'per_km', 'hourly', 'weight', 'volume', 'custom_quote'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- Reference data: platform-defined service categories (admin-managed only)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_categories (
    id TEXT PRIMARY KEY,
    domain service_domain NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_service_categories_domain_name ON service_categories (domain, name);
CREATE INDEX IF NOT EXISTS idx_service_categories_domain ON service_categories (domain, is_active);

-- Reference data: platform-defined capabilities/options per domain
CREATE TABLE IF NOT EXISTS service_capabilities (
    id TEXT PRIMARY KEY,
    domain service_domain NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_service_capabilities_domain_name ON service_capabilities (domain, name);
CREATE INDEX IF NOT EXISTS idx_service_capabilities_domain ON service_capabilities (domain, is_active);

-- ---------------------------------------------------------------------------
-- Provider service offerings
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS provider_service_offerings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    specialized_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE CASCADE,
    domain service_domain NOT NULL,
    category_id TEXT NOT NULL REFERENCES service_categories(id),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    service_type VARCHAR(80),
    status provider_offering_status NOT NULL DEFAULT 'draft',
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    temporary_unavailable_from DATE,
    temporary_unavailable_to DATE,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_offering_temp_window CHECK (
        temporary_unavailable_to IS NULL
        OR temporary_unavailable_from IS NULL
        OR temporary_unavailable_to >= temporary_unavailable_from
    ),
    CONSTRAINT chk_offering_category_domain CHECK (category_id IS NOT NULL)
);
-- One offering per profile + category (prevents duplicate offerings).
CREATE UNIQUE INDEX IF NOT EXISTS uq_provider_offerings_profile_category
    ON provider_service_offerings (specialized_profile_id, category_id);
CREATE INDEX IF NOT EXISTS idx_provider_offerings_profile ON provider_service_offerings (specialized_profile_id, status);
CREATE INDEX IF NOT EXISTS idx_provider_offerings_domain_status ON provider_service_offerings (domain, status);

CREATE OR REPLACE FUNCTION update_provider_service_offerings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_provider_service_offerings_updated_at ON provider_service_offerings;
CREATE TRIGGER trigger_update_provider_service_offerings_updated_at
    BEFORE UPDATE ON provider_service_offerings
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_service_offerings_updated_at();

-- Per-offering capabilities (normalized; a provider only enables what it offers)
CREATE TABLE IF NOT EXISTS provider_service_offering_capabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offering_id UUID NOT NULL REFERENCES provider_service_offerings(id) ON DELETE CASCADE,
    capability_id TEXT NOT NULL REFERENCES service_capabilities(id),
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    detail TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (offering_id, capability_id)
);
CREATE INDEX IF NOT EXISTS idx_offering_capabilities_offering ON provider_service_offering_capabilities (offering_id);

-- Per-offering pricing configuration (1:1). Exact decimal storage; KES default.
CREATE TABLE IF NOT EXISTS provider_service_pricing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offering_id UUID NOT NULL UNIQUE REFERENCES provider_service_offerings(id) ON DELETE CASCADE,
    pricing_model pricing_model NOT NULL DEFAULT 'custom_quote',
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    base_amount NUMERIC(12, 2),
    minimum_charge NUMERIC(12, 2),
    unit_label VARCHAR(50),
    quotation_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_indicative BOOLEAN NOT NULL DEFAULT TRUE,
    price_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_pricing_amounts_nonneg CHECK (
        (base_amount IS NULL OR base_amount >= 0)
        AND (minimum_charge IS NULL OR minimum_charge >= 0)
    )
);

CREATE OR REPLACE FUNCTION update_provider_service_pricing_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_provider_service_pricing_updated_at ON provider_service_pricing;
CREATE TRIGGER trigger_update_provider_service_pricing_updated_at
    BEFORE UPDATE ON provider_service_pricing
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_service_pricing_updated_at();

-- ---------------------------------------------------------------------------
-- Offering-scoped service areas (reuse provider_service_areas; additive column)
--   offering_id NULL  => profile-level coverage (legacy behaviour preserved)
--   offering_id set   => coverage specific to one offering/category
-- ---------------------------------------------------------------------------
ALTER TABLE provider_service_areas
    ADD COLUMN IF NOT EXISTS offering_id UUID REFERENCES provider_service_offerings(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_provider_service_areas_offering ON provider_service_areas (offering_id);

-- ---------------------------------------------------------------------------
-- Business locations: extend saved_locations (no duplicate location system)
-- ---------------------------------------------------------------------------
ALTER TABLE saved_locations ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE saved_locations ADD COLUMN IF NOT EXISTS visibility VARCHAR(20) NOT NULL DEFAULT 'private';
ALTER TABLE saved_locations ADD COLUMN IF NOT EXISTS organisation_id UUID REFERENCES organisations(id) ON DELETE CASCADE;
ALTER TABLE saved_locations ADD COLUMN IF NOT EXISTS is_primary BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE saved_locations ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_saved_locations_org ON saved_locations (organisation_id, is_active);
CREATE INDEX IF NOT EXISTS idx_saved_locations_public ON saved_locations (is_public, location_type);

-- Enforce a single primary location per organization and per individual user.
DO $$ BEGIN
  CREATE UNIQUE INDEX uq_saved_locations_primary_org
      ON saved_locations (organisation_id)
      WHERE is_primary AND is_active AND organisation_id IS NOT NULL;
EXCEPTION WHEN duplicate_table THEN NULL; END $$;

DO $$ BEGIN
  CREATE UNIQUE INDEX uq_saved_locations_primary_user
      ON saved_locations (user_id)
      WHERE is_primary AND is_active AND organisation_id IS NULL;
EXCEPTION WHEN duplicate_table THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- Provider operating hours (reusable; profile-wide or offering-specific)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS provider_operating_hours (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    specialized_profile_id UUID REFERENCES specialized_profiles(id) ON DELETE CASCADE,
    offering_id UUID REFERENCES provider_service_offerings(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    open_time TIME NOT NULL,
    close_time TIME NOT NULL,
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    time_zone TEXT NOT NULL DEFAULT 'Africa/Nairobi',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_operating_hours_scope CHECK (
        specialized_profile_id IS NOT NULL OR offering_id IS NOT NULL
    ),
    CONSTRAINT chk_operating_hours_window CHECK (close_time > open_time OR is_closed)
);
CREATE INDEX IF NOT EXISTS idx_provider_operating_hours_profile ON provider_operating_hours (specialized_profile_id);
CREATE INDEX IF NOT EXISTS idx_provider_operating_hours_offering ON provider_operating_hours (offering_id);

CREATE OR REPLACE FUNCTION update_provider_operating_hours_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_provider_operating_hours_updated_at ON provider_operating_hours;
CREATE TRIGGER trigger_update_provider_operating_hours_updated_at
    BEFORE UPDATE ON provider_operating_hours
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_operating_hours_updated_at();

-- Availability exceptions (temporary closures / special-day overrides)
CREATE TABLE IF NOT EXISTS provider_availability_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    specialized_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE CASCADE,
    offering_id UUID REFERENCES provider_service_offerings(id) ON DELETE CASCADE,
    exception_date DATE NOT NULL,
    is_unavailable BOOLEAN NOT NULL DEFAULT TRUE,
    start_time TIME,
    end_time TIME,
    reason TEXT,
    time_zone TEXT NOT NULL DEFAULT 'Africa/Nairobi',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (specialized_profile_id, offering_id, exception_date)
);
CREATE INDEX IF NOT EXISTS idx_provider_availability_exceptions_profile ON provider_availability_exceptions (specialized_profile_id, exception_date);

CREATE OR REPLACE FUNCTION update_provider_availability_exceptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_provider_availability_exceptions_updated_at ON provider_availability_exceptions;
CREATE TRIGGER trigger_update_provider_availability_exceptions_updated_at
    BEFORE UPDATE ON provider_availability_exceptions
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_availability_exceptions_updated_at();

-- ---------------------------------------------------------------------------
-- Seed platform reference data (idempotent)
-- ---------------------------------------------------------------------------
INSERT INTO service_categories (id, domain, name, description, sort_order) VALUES
    ('moving_household', 'moving', 'Household moving', 'Full household relocation', 10),
    ('moving_apartment', 'moving', 'Apartment moving', 'Apartment/unit relocation', 20),
    ('moving_office', 'moving', 'Office moving', 'Office relocation', 30),
    ('moving_commercial', 'moving', 'Commercial moving', 'Commercial premises relocation', 40),
    ('moving_local', 'moving', 'Local moving', 'Local (same town/county) moves', 50),
    ('moving_long_distance', 'moving', 'Long-distance moving', 'Inter-town/county moves', 60),
    ('moving_furniture', 'moving', 'Furniture transport', 'Furniture-only transport', 70),
    ('moving_appliance', 'moving', 'Appliance transport', 'Appliance-only transport', 80),
    ('moving_packing', 'moving', 'Packing and unpacking', 'Packing/unpacking service', 90),
    ('moving_loading', 'moving', 'Loading and unloading', 'Loading/unloading service', 100),
    ('garbage_residential', 'garbage', 'Residential waste collection', 'Household waste collection', 10),
    ('garbage_commercial', 'garbage', 'Commercial waste collection', 'Business waste collection', 20),
    ('garbage_estate', 'garbage', 'Apartment/estate collection', 'Estate/apartment collection', 30),
    ('garbage_scheduled', 'garbage', 'Scheduled collection', 'Recurring scheduled collection', 40),
    ('garbage_one_time', 'garbage', 'One-time collection', 'One-off collection', 50),
    ('garbage_bulk', 'garbage', 'Bulk waste collection', 'Bulk waste collection', 60),
    ('garbage_recycling', 'garbage', 'Recycling collection', 'Recyclables collection', 70),
    ('laundry_washing', 'laundry', 'Washing', 'Washing service', 10),
    ('laundry_drying', 'laundry', 'Drying', 'Drying service', 20),
    ('laundry_ironing', 'laundry', 'Ironing', 'Ironing service', 30),
    ('laundry_dry_cleaning', 'laundry', 'Dry cleaning', 'Dry cleaning (where offered)', 40),
    ('laundry_folding', 'laundry', 'Folding', 'Folding service', 50),
    ('laundry_bedding', 'laundry', 'Bedding and linen cleaning', 'Bedding/linen cleaning', 60),
    ('laundry_household', 'laundry', 'Household laundry', 'Household laundry', 70),
    ('laundry_commercial', 'laundry', 'Commercial laundry', 'Commercial laundry', 80),
    ('laundry_pickup_delivery', 'laundry', 'Pickup and delivery', 'Pickup/delivery service', 90)
ON CONFLICT (id) DO NOTHING;

INSERT INTO service_capabilities (id, domain, name, description, sort_order) VALUES
    ('moving_packing', 'moving', 'Packing', 'Packing availability', 10),
    ('moving_loading', 'moving', 'Loading', 'Loading availability', 20),
    ('moving_unloading', 'moving', 'Unloading', 'Unloading availability', 30),
    ('moving_furniture_handling', 'moving', 'Furniture handling', 'Furniture handling', 40),
    ('moving_fragile_handling', 'moving', 'Fragile-item handling', 'Fragile-item handling', 50),
    ('moving_appliance_handling', 'moving', 'Appliance handling', 'Appliance handling', 60),
    ('garbage_residential_eligibility', 'garbage', 'Residential eligibility', 'Serves residential clients', 10),
    ('garbage_commercial_eligibility', 'garbage', 'Commercial eligibility', 'Serves commercial clients', 20),
    ('garbage_scheduled_collection', 'garbage', 'Scheduled collection', 'Recurring collection', 30),
    ('garbage_one_time_collection', 'garbage', 'One-time collection', 'One-off collection', 40),
    ('garbage_recycling', 'garbage', 'Recycling', 'Recycling collection', 50),
    ('laundry_washing', 'laundry', 'Washing', 'Washing', 10),
    ('laundry_drying', 'laundry', 'Drying', 'Drying', 20),
    ('laundry_ironing', 'laundry', 'Ironing', 'Ironing', 30),
    ('laundry_dry_cleaning', 'laundry', 'Dry cleaning', 'Dry cleaning', 40),
    ('laundry_folding', 'laundry', 'Folding', 'Folding', 50),
    ('laundry_bedding_cleaning', 'laundry', 'Bedding cleaning', 'Bedding/linen cleaning', 60),
    ('laundry_pickup', 'laundry', 'Pickup', 'Pickup availability', 70),
    ('laundry_delivery', 'laundry', 'Delivery', 'Delivery availability', 80)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Seed catalogue permissions (additive, idempotent) and grant to provider roles
-- ---------------------------------------------------------------------------
INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.catalogue.read', 'View Provider Service Catalogue', 'View service categories and own offerings', 'provider', FALSE),
    ('provider.catalogue.manage', 'Manage Provider Service Catalogue', 'Create/edit offerings, pricing, capabilities', 'provider', FALSE),
    ('provider.locations.manage', 'Manage Provider Locations', 'Manage business/operating locations', 'provider', FALSE),
    ('provider.availability.manage', 'Manage Provider Availability', 'Manage operating hours and closures', 'provider', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('moving_company', 'individual_mover', 'garbage_provider', 'laundry_provider', 'service_provider')
   AND p.id IN ('provider.catalogue.read', 'provider.catalogue.manage', 'provider.locations.manage', 'provider.availability.manage')
ON CONFLICT (role_id, permission_id) DO NOTHING;