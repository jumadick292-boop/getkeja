-- Migration: 100_create_moving_requests
-- Description: Create moving_requests and moving_status_history tables for
--   tenant moving service request workflows.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'moving_request_status') THEN
        CREATE TYPE moving_request_status AS ENUM (
            'submitted', 'pending_confirmation', 'accepted', 'scheduled',
            'in_progress', 'completed', 'declined', 'cancelled'
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'moving_service_type') THEN
        CREATE TYPE moving_service_type AS ENUM (
            'local_move', 'long_distance_move', 'international_move',
            'office_move', 'furniture_move', 'packing_only', 'loading_unloading_only', 'other'
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS moving_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    provider_id UUID REFERENCES specialized_profiles(id) ON DELETE SET NULL,
    service_type moving_service_type NOT NULL DEFAULT 'other',
    pickup_location TEXT NOT NULL,
    destination_location TEXT NOT NULL,
    pickup_latitude DECIMAL(10, 8),
    pickup_longitude DECIMAL(11, 8),
    destination_latitude DECIMAL(10, 8),
    destination_longitude DECIMAL(11, 8),
    preferred_date_time TIMESTAMPTZ,
    item_description TEXT,
    special_instructions TEXT,
    contact_name VARCHAR(200),
    contact_phone VARCHAR(50),
    contact_email VARCHAR(254),
    status moving_request_status NOT NULL DEFAULT 'submitted',
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

CREATE INDEX IF NOT EXISTS idx_moving_requests_property_id ON moving_requests (property_id);
CREATE INDEX IF NOT EXISTS idx_moving_requests_unit_id ON moving_requests (unit_id);
CREATE INDEX IF NOT EXISTS idx_moving_requests_tenancy_id ON moving_requests (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_moving_requests_tenant_id ON moving_requests (tenant_id);
CREATE INDEX IF NOT EXISTS idx_moving_requests_provider_id ON moving_requests (provider_id);
CREATE INDEX IF NOT EXISTS idx_moving_requests_status ON moving_requests (status);
CREATE INDEX IF NOT EXISTS idx_moving_requests_service_type ON moving_requests (service_type);
CREATE INDEX IF NOT EXISTS idx_moving_requests_created_at ON moving_requests (created_at DESC);

CREATE TABLE IF NOT EXISTS moving_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moving_request_id UUID NOT NULL REFERENCES moving_requests(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    previous_status moving_request_status,
    new_status moving_request_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_moving_status_history_request_id ON moving_status_history (moving_request_id);
CREATE INDEX IF NOT EXISTS idx_moving_status_history_created_at ON moving_status_history (created_at DESC);

CREATE OR REPLACE FUNCTION update_moving_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_moving_requests_updated_at ON moving_requests;
CREATE TRIGGER trigger_update_moving_requests_updated_at
    BEFORE UPDATE ON moving_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_moving_requests_updated_at();

CREATE OR REPLACE FUNCTION record_moving_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO moving_status_history (moving_request_id, action, previous_status, new_status, changed_by, change_reason)
        VALUES (OLD.id, 'status_change', OLD.status, NEW.status, COALESCE(NEW.updated_by, OLD.created_by), 'Status changed via API');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_moving_status_history ON moving_requests;
CREATE TRIGGER trigger_record_moving_status_history
    BEFORE UPDATE ON moving_requests
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_moving_status_history();
