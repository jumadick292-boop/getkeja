-- Migration: 101_create_laundry_requests
-- Description: Create laundry_requests and laundry_status_history tables for
--   tenant laundry service request workflows.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'laundry_request_status') THEN
        CREATE TYPE laundry_request_status AS ENUM (
            'submitted', 'pending_confirmation', 'accepted', 'scheduled',
            'in_progress', 'completed', 'declined', 'cancelled'
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'laundry_service_category') THEN
        CREATE TYPE laundry_service_category AS ENUM (
            'wash_fold', 'dry_clean', 'iron_only', 'bedding_cleaning',
            'household_textile_cleaning', 'other'
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'laundry_collection_preference') THEN
        CREATE TYPE laundry_collection_preference AS ENUM (
            'doorstep', 'lobby', 'designated_area'
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS laundry_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    provider_id UUID REFERENCES specialized_profiles(id) ON DELETE SET NULL,
    service_category laundry_service_category NOT NULL DEFAULT 'other',
    collection_preference laundry_collection_preference NOT NULL DEFAULT 'doorstep',
    preferred_date_time TIMESTAMPTZ,
    garment_count INTEGER,
    special_instructions TEXT,
    contact_name VARCHAR(200),
    contact_phone VARCHAR(50),
    contact_email VARCHAR(254),
    status laundry_request_status NOT NULL DEFAULT 'submitted',
    scheduled_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_laundry_garment_count CHECK (garment_count IS NULL OR garment_count > 0)
);

CREATE INDEX IF NOT EXISTS idx_laundry_requests_property_id ON laundry_requests (property_id);
CREATE INDEX IF NOT EXISTS idx_laundry_requests_unit_id ON laundry_requests (unit_id);
CREATE INDEX IF NOT EXISTS idx_laundry_requests_tenancy_id ON laundry_requests (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_laundry_requests_tenant_id ON laundry_requests (tenant_id);
CREATE INDEX IF NOT EXISTS idx_laundry_requests_provider_id ON laundry_requests (provider_id);
CREATE INDEX IF NOT EXISTS idx_laundry_requests_status ON laundry_requests (status);
CREATE INDEX IF NOT EXISTS idx_laundry_requests_service_category ON laundry_requests (service_category);
CREATE INDEX IF NOT EXISTS idx_laundry_requests_created_at ON laundry_requests (created_at DESC);

CREATE TABLE IF NOT EXISTS laundry_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    laundry_request_id UUID NOT NULL REFERENCES laundry_requests(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    previous_status laundry_request_status,
    new_status laundry_request_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_laundry_status_history_request_id ON laundry_status_history (laundry_request_id);
CREATE INDEX IF NOT EXISTS idx_laundry_status_history_created_at ON laundry_status_history (created_at DESC);

CREATE OR REPLACE FUNCTION update_laundry_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_laundry_requests_updated_at ON laundry_requests;
CREATE TRIGGER trigger_update_laundry_requests_updated_at
    BEFORE UPDATE ON laundry_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_laundry_requests_updated_at();

CREATE OR REPLACE FUNCTION record_laundry_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO laundry_status_history (laundry_request_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_laundry_status_history ON laundry_requests;
CREATE TRIGGER trigger_record_laundry_status_history
    BEFORE UPDATE ON laundry_requests
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_laundry_status_history();
