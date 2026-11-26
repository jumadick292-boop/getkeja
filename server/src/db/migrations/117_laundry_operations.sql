-- Migration: 117_laundry_operations
-- Description: Task 13.8 — laundry provider operations built on the 13.5
--   marketplace and the 13.6/13.7 operational pattern. Adds a quotation-driven
--   operational order with item-level intake/inventory accountability,
--   inspection/discrepancy approval, processing stages, collection/return
--   handover, amendments and exceptions. Legacy laundry_requests /
--   laundry_provider_services are left untouched. Additive and idempotent.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'laundry_collection_status') THEN
        CREATE TYPE laundry_collection_status AS ENUM (
            'confirmed', 'collection_scheduled', 'collected', 'received_at_facility',
            'inspection', 'awaiting_customer_approval', 'processing', 'washing',
            'drying', 'ironing', 'folding', 'quality_check', 'ready_for_return',
            'out_for_delivery', 'delivered', 'awaiting_customer_confirmation',
            'completed', 'cancelled', 'failed', 'exception'
        );
    END IF;
END $$;

-- laundry_orders — one operational order per accepted marketplace quotation.
CREATE TABLE IF NOT EXISTS laundry_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE RESTRICT,
    quotation_id UUID NOT NULL REFERENCES service_quotations(id) ON DELETE RESTRICT,
    quotation_version INTEGER NOT NULL,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    assigned_staff_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status laundry_collection_status NOT NULL DEFAULT 'confirmed',
    -- Collection / return preferences.
    fulfilment_mode VARCHAR(32) NOT NULL DEFAULT 'dropoff',
    collection_location_id UUID,
    collection_address TEXT,
    return_location_id UUID,
    return_address TEXT,
    property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    agreed_price NUMERIC(12,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'KES',
    scope JSONB NOT NULL DEFAULT '{}'::jsonb,
    checklist JSONB NOT NULL DEFAULT '{}'::jsonb,
    collection_date DATE,
    collection_window_start VARCHAR(8),
    collection_window_end VARCHAR(8),
    return_date DATE,
    return_window_start VARCHAR(8),
    return_window_end VARCHAR(8),
    completion_notes TEXT,
    completion_submitted_at TIMESTAMPTZ,
    completion_outstanding_issue BOOLEAN NOT NULL DEFAULT FALSE,
    customer_confirmation_status VARCHAR(32) NOT NULL DEFAULT 'pending',
    customer_confirmation_notes TEXT,
    customer_confirmation_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    cancellation_reason TEXT,
    failed_at TIMESTAMPTZ,
    failure_reason TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_laundry_order_price_nonneg CHECK (agreed_price >= 0),
    CONSTRAINT chk_laundry_order_fulfilment CHECK (fulfilment_mode IN ('dropoff','collection','both'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_laundry_orders_request ON laundry_orders (service_request_id);
CREATE INDEX IF NOT EXISTS idx_laundry_orders_customer ON laundry_orders (customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_laundry_orders_provider ON laundry_orders (provider_profile_id, status);
CREATE INDEX IF NOT EXISTS idx_laundry_orders_status ON laundry_orders (status, return_date);
CREATE INDEX IF NOT EXISTS idx_laundry_orders_staff ON laundry_orders (assigned_staff_user_id);

CREATE OR REPLACE FUNCTION update_laundry_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_laundry_orders_updated_at ON laundry_orders;
CREATE TRIGGER trigger_update_laundry_orders_updated_at
    BEFORE UPDATE ON laundry_orders FOR EACH ROW EXECUTE FUNCTION update_laundry_orders_updated_at();

-- laundry_order_history — append-only audit (+ status trigger).
CREATE TABLE IF NOT EXISTS laundry_order_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    laundry_order_id UUID NOT NULL REFERENCES laundry_orders(id) ON DELETE CASCADE,
    action VARCHAR(64) NOT NULL,
    previous_status laundry_collection_status,
    new_status laundry_collection_status,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_laundry_order_history_order ON laundry_order_history (laundry_order_id, created_at DESC);

CREATE OR REPLACE FUNCTION record_laundry_order_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO laundry_order_history (laundry_order_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_laundry_order_history ON laundry_orders;
CREATE TRIGGER trigger_record_laundry_order_history
    BEFORE UPDATE ON laundry_orders FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_laundry_order_history();

-- laundry_order_items — item-level intake / inventory accountability.
CREATE TABLE IF NOT EXISTS laundry_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    laundry_order_id UUID NOT NULL REFERENCES laundry_orders(id) ON DELETE CASCADE,
    item_category VARCHAR(80) NOT NULL DEFAULT 'garment',
    description TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    customer_reference VARCHAR(120),
    condition_at_intake VARCHAR(32),
    stains_damage_notes TEXT,
    special_handling TEXT,
    processing_instructions TEXT,
    item_status VARCHAR(32) NOT NULL DEFAULT 'received',
    return_condition_notes TEXT,
    handover_notes TEXT,
    photo_document_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_laundry_item_qty CHECK (quantity > 0)
);
CREATE INDEX IF NOT EXISTS idx_laundry_order_items_order ON laundry_order_items (laundry_order_id);

-- laundry_order_inspections — intake inspection + discrepancy/approval.
CREATE TABLE IF NOT EXISTS laundry_order_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    laundry_order_id UUID NOT NULL REFERENCES laundry_orders(id) ON DELETE CASCADE,
    item_id UUID REFERENCES laundry_order_items(id) ON DELETE SET NULL,
    reported_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    result VARCHAR(32) NOT NULL DEFAULT 'ok',
    declared_quantity INTEGER,
    received_quantity INTEGER,
    description TEXT,
    requires_customer_approval BOOLEAN NOT NULL DEFAULT FALSE,
    approval_status VARCHAR(24) NOT NULL DEFAULT 'not_required',
    decided_by UUID REFERENCES users(id) ON DELETE SET NULL,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_laundry_order_inspections_order ON laundry_order_inspections (laundry_order_id);

-- laundry_order_staff_assignments — explicit, revocable staff access.
CREATE TABLE IF NOT EXISTS laundry_order_staff_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    laundry_order_id UUID NOT NULL REFERENCES laundry_orders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(120),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_laundry_order_active_staff
    ON laundry_order_staff_assignments (laundry_order_id, user_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_laundry_order_staff_order ON laundry_order_staff_assignments (laundry_order_id, is_active);

-- laundry_order_handovers — collection / return scheduling + proof.
CREATE TABLE IF NOT EXISTS laundry_order_handovers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    laundry_order_id UUID NOT NULL REFERENCES laundry_orders(id) ON DELETE CASCADE,
    kind VARCHAR(16) NOT NULL,
    status VARCHAR(24) NOT NULL DEFAULT 'scheduled',
    location_id UUID,
    address TEXT,
    scheduled_at TIMESTAMPTZ,
    window_start VARCHAR(8),
    window_end VARCHAR(8),
    notes TEXT,
    proof_document_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    confirmed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    confirmed_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_laundry_handover_kind CHECK (kind IN ('collection','return'))
);
CREATE INDEX IF NOT EXISTS idx_laundry_order_handovers_order ON laundry_order_handovers (laundry_order_id, kind);

-- laundry_order_amendments — explicit change/approval (accepted quotation immutable).
CREATE TABLE IF NOT EXISTS laundry_order_amendments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    laundry_order_id UUID NOT NULL REFERENCES laundry_orders(id) ON DELETE CASCADE,
    proposed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL,
    revised_scope JSONB NOT NULL DEFAULT '{}'::jsonb,
    additional_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'KES',
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    decided_by UUID REFERENCES users(id) ON DELETE SET NULL,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_laundry_order_amendments_order ON laundry_order_amendments (laundry_order_id, status);

-- laundry_order_exceptions — operational exceptions (missing/damaged/delayed/etc).
CREATE TABLE IF NOT EXISTS laundry_order_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    laundry_order_id UUID NOT NULL REFERENCES laundry_orders(id) ON DELETE CASCADE,
    reported_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    type VARCHAR(40) NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_laundry_order_exceptions_order ON laundry_order_exceptions (laundry_order_id);

-- laundry_order_attachments — loose document references, access-controlled.
CREATE TABLE IF NOT EXISTS laundry_order_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    laundry_order_id UUID NOT NULL REFERENCES laundry_orders(id) ON DELETE CASCADE,
    document_id UUID NOT NULL,
    kind VARCHAR(32) NOT NULL DEFAULT 'evidence',
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (laundry_order_id, document_id)
);
CREATE INDEX IF NOT EXISTS idx_laundry_order_attachments_order ON laundry_order_attachments (laundry_order_id);

-- Permissions (idempotent) + grants to laundry roles.
INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.laundry.view', 'View Laundry Orders', 'View assigned laundry orders', 'provider', FALSE),
    ('provider.laundry.view_locations', 'View Laundry Locations', 'View collection/return addresses', 'provider', FALSE),
    ('provider.laundry.update_progress', 'Update Laundry Progress', 'Advance processing stages', 'provider', FALSE),
    ('provider.laundry.manage_intake', 'Manage Laundry Intake', 'Record items and inspections', 'provider', FALSE),
    ('provider.laundry.manage_schedule', 'Manage Laundry Schedule', 'Schedule/reschedule handovers', 'provider', FALSE),
    ('provider.laundry.upload_evidence', 'Upload Laundry Evidence', 'Upload handover/completion evidence', 'provider', FALSE),
    ('provider.laundry.assign_staff', 'Assign Laundry Staff', 'Assign authorized staff', 'provider', FALSE),
    ('provider.laundry.propose_changes', 'Propose Laundry Changes', 'Propose amendments', 'provider', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('laundry_provider', 'service_provider')
   AND p.id IN (
     'provider.laundry.view', 'provider.laundry.view_locations',
     'provider.laundry.update_progress', 'provider.laundry.manage_intake',
     'provider.laundry.manage_schedule', 'provider.laundry.upload_evidence',
     'provider.laundry.assign_staff', 'provider.laundry.propose_changes'
   )
ON CONFLICT (role_id, permission_id) DO NOTHING;