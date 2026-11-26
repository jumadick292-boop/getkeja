-- Migration: 109_service_marketplace
-- Description: Task 13.5 — unified service-request + quotation marketplace.
--   Seeds 18 marketplace categories (+ per-domain capabilities) on top of the
--   catalogue from 107, and introduces ONE reusable request engine shared by all
--   categories:
--     * service_requests            (customer request, category-scoped details)
--     * service_request_history     (append-only status/transition audit)
--     * service_quotations          (provider quotations, append-only revisions)
--     * service_quotation_items     (line items per quotation)
--     * service_request_attachments (link to existing private-document storage)
--   Legacy moving/laundry/garbage tenant endpoints are untouched; this engine is
--   additive. Additive and idempotent: safe on fresh and populated databases.

-- ---------------------------------------------------------------------------
-- Enums (guarded)
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE service_request_status AS ENUM (
    'open', 'quoted', 'accepted', 'in_progress', 'completed', 'cancelled', 'expired'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE service_quotation_status AS ENUM (
    'submitted', 'revised', 'accepted', 'declined', 'withdrawn', 'expired'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- Seed 18 marketplace categories across the extended domains (idempotent).
--   IDs are stable slugs so the Flutter client and tests can reference them.
-- ---------------------------------------------------------------------------
INSERT INTO service_categories (id, domain, name, description, sort_order) VALUES
  ('clean_home',        'cleaning',    'Home cleaning',          'Routine home cleaning', 110),
  ('clean_deep',        'cleaning',    'Deep cleaning',          'Intensive deep cleaning', 120),
  ('clean_office',      'cleaning',    'Office cleaning',        'Commercial office cleaning', 130),
  ('plumbing_general',  'plumbing',    'Plumbing',               'General plumbing repairs', 140),
  ('plumbing_emergency','plumbing',    'Emergency plumbing',     'Urgent plumbing response', 150),
  ('electrical_general','electrical',  'Electrical',             'General electrical work', 160),
  ('electrical_wiring', 'electrical',  'Wiring and rewiring',    'Wiring installation/upgrade', 170),
  ('hvac_service',      'hvac',        'HVAC service',           'Heating, ventilation, AC', 180),
  ('pest_control_general','pest_control','Pest control',         'Fumigation and pest control', 190),
  ('landscaping_general','landscaping','Landscaping',            'Landscaping and grounds', 200),
  ('gardening',         'landscaping', 'Gardening',              'Garden maintenance', 210),
  ('carpentry',         'carpentry',   'Carpentry',              'Woodwork and carpentry', 220),
  ('painting',          'painting',    'Painting',               'Interior/exterior painting', 230),
  ('roofing',           'roofing',     'Roofing',                'Roof repair and installation', 240),
  ('flooring',          'flooring',    'Flooring',               'Floor installation and repair', 250),
  ('tiling',            'tiling',      'Tiling',                 'Wall and floor tiling', 260),
  ('appliance_repair',  'appliances',  'Appliance repair',       'Home appliance repair', 270),
  ('handyman',          'general',     'Handyman',               'General home repairs and odd jobs', 280)
ON CONFLICT (id) DO NOTHING;

-- Per-domain capabilities for the new marketplace domains (idempotent).
INSERT INTO service_capabilities (id, domain, name, description, sort_order) VALUES
  ('cleaning_supplies',   'cleaning',   'Supplies included',    'Provider brings supplies', 10),
  ('cleaning_ecofriendly','cleaning',   'Eco-friendly',         'Eco-friendly products', 20),
  ('plumbing_emergency',  'plumbing',   'Emergency callout',    '24/7 emergency callout', 10),
  ('electrical_certified','electrical', 'Certified electrician','Certified/licensed', 10),
  ('hvac_maintenance',    'hvac',       'Maintenance contract', 'Scheduled maintenance', 10),
  ('pest_certified',      'pest_control','Certified applicator','Licensed pest control', 10),
  ('landscaping_mow',     'landscaping','Mowing',               'Lawn mowing', 10),
  ('carpentry_custom',    'carpentry',  'Custom builds',        'Custom woodwork', 10),
  ('painting_exterior',   'painting',   'Exterior painting',    'Exterior surfaces', 10),
  ('roofing_emergency',   'roofing',    'Emergency repair',     'Emergency roof repair', 10),
  ('flooring_install',    'flooring',   'Installation',         'New floor installation', 10),
  ('tiling_waterproof',   'tiling',     'Waterproofing',        'Wet-area waterproofing', 10),
  ('appliance_diagnostic','appliances', 'Diagnostics',          'On-site diagnostics', 10),
  ('handyman_multi',      'general',    'Multi-trade',          'Multiple trades', 10)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- service_requests — one row per customer request, any category.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id TEXT NOT NULL REFERENCES service_categories(id),
    domain service_domain NOT NULL,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status service_request_status NOT NULL DEFAULT 'open',
    title VARCHAR(200),
    description TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    saved_location_id UUID REFERENCES saved_locations(id) ON DELETE SET NULL,
    service_address TEXT,
    service_county VARCHAR(120),
    service_city VARCHAR(120),
    service_latitude DECIMAL(10, 8),
    service_longitude DECIMAL(11, 8),
    preferred_date_time TIMESTAMPTZ,
    contact_name VARCHAR(200),
    contact_phone VARCHAR(50),
    contact_email VARCHAR(254),
    accepted_quotation_id UUID,
    assigned_provider_id UUID REFERENCES specialized_profiles(id) ON DELETE SET NULL,
    scheduled_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_service_requests_customer ON service_requests (customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_service_requests_status ON service_requests (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_service_requests_category ON service_requests (category_id, status);
CREATE INDEX IF NOT EXISTS idx_service_requests_domain ON service_requests (domain, status);
CREATE INDEX IF NOT EXISTS idx_service_requests_assigned ON service_requests (assigned_provider_id, status);
CREATE INDEX IF NOT EXISTS idx_service_requests_county ON service_requests (service_county);

CREATE OR REPLACE FUNCTION update_service_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_service_requests_updated_at ON service_requests;
CREATE TRIGGER trigger_update_service_requests_updated_at
    BEFORE UPDATE ON service_requests
    FOR EACH ROW EXECUTE FUNCTION update_service_requests_updated_at();

-- ---------------------------------------------------------------------------
-- service_request_history — append-only transition audit.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_request_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    previous_status service_request_status,
    new_status service_request_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_service_request_history_request ON service_request_history (service_request_id, created_at DESC);

CREATE OR REPLACE FUNCTION record_service_request_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO service_request_history (service_request_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_service_request_history ON service_requests;
CREATE TRIGGER trigger_record_service_request_history
    BEFORE UPDATE ON service_requests
    FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_service_request_history();

-- ---------------------------------------------------------------------------
-- service_quotations — provider quotations with append-only revisions.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL DEFAULT 1,
    status service_quotation_status NOT NULL DEFAULT 'submitted',
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    subtotal_amount NUMERIC(12, 2) NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    estimated_start TIMESTAMPTZ,
    estimated_completion TIMESTAMPTZ,
    valid_until TIMESTAMPTZ NOT NULL,
    terms TEXT,
    notes TEXT,
    supersedes_id UUID REFERENCES service_quotations(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_quotation_amounts_nonneg CHECK (subtotal_amount >= 0 AND total_amount >= 0),
    CONSTRAINT chk_quotation_total_gte_subtotal CHECK (total_amount >= subtotal_amount),
    UNIQUE (service_request_id, provider_profile_id, version_number)
);
CREATE INDEX IF NOT EXISTS idx_service_quotations_request ON service_quotations (service_request_id, status);
CREATE INDEX IF NOT EXISTS idx_service_quotations_provider ON service_quotations (provider_profile_id, created_at DESC);

-- At most one live (submitted/revised) quotation per provider per request.
CREATE UNIQUE INDEX IF NOT EXISTS uq_service_quotations_live
    ON service_quotations (service_request_id, provider_profile_id)
    WHERE status IN ('submitted', 'revised');

CREATE OR REPLACE FUNCTION update_service_quotations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_service_quotations_updated_at ON service_quotations;
CREATE TRIGGER trigger_update_service_quotations_updated_at
    BEFORE UPDATE ON service_quotations
    FOR EACH ROW EXECUTE FUNCTION update_service_quotations_updated_at();

-- Now that service_quotations exists, wire the request -> accepted quotation FK.
ALTER TABLE service_requests
    DROP CONSTRAINT IF EXISTS fk_service_requests_accepted_quotation;
ALTER TABLE service_requests
    ADD CONSTRAINT fk_service_requests_accepted_quotation
    FOREIGN KEY (accepted_quotation_id) REFERENCES service_quotations(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- service_quotation_items — line items per quotation.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_quotation_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id UUID NOT NULL REFERENCES service_quotations(id) ON DELETE CASCADE,
    description VARCHAR(200) NOT NULL,
    quantity NUMERIC(12, 2) NOT NULL DEFAULT 1,
    unit_price NUMERIC(12, 2) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_quotation_item_nonneg CHECK (quantity > 0 AND unit_price >= 0 AND amount >= 0)
);
CREATE INDEX IF NOT EXISTS idx_service_quotation_items_quotation ON service_quotation_items (quotation_id, sort_order);

-- ---------------------------------------------------------------------------
-- service_request_attachments — link to existing private-document storage.
--   document_id references the private-document subsystem; kept as a loose UUID
--   reference so this engine does not couple to that module's table directly.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_request_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    document_id UUID NOT NULL,
    kind VARCHAR(20) NOT NULL DEFAULT 'evidence',
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (service_request_id, document_id)
);
CREATE INDEX IF NOT EXISTS idx_service_request_attachments_request ON service_request_attachments (service_request_id);

-- ---------------------------------------------------------------------------
-- Marketplace permissions (additive, idempotent) + grant to provider roles.
-- ---------------------------------------------------------------------------
INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.marketplace.respond', 'Respond to Service Requests', 'Submit and revise quotations on marketplace requests', 'provider', FALSE),
    ('provider.marketplace.manage', 'Manage Marketplace Quotations', 'Withdraw quotations and manage the provider quotation inbox', 'provider', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('moving_company', 'individual_mover', 'garbage_provider', 'laundry_provider', 'service_provider')
   AND p.id IN ('provider.marketplace.respond', 'provider.marketplace.manage')
ON CONFLICT (role_id, permission_id) DO NOTHING;