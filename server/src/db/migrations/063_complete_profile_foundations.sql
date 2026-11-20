ALTER TABLE organisations
    ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 8),
    ADD COLUMN IF NOT EXISTS longitude NUMERIC(11, 8),
    ADD COLUMN IF NOT EXISTS place_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS neighbourhood VARCHAR(100),
    ADD COLUMN IF NOT EXISTS location_source location_source,
    ADD COLUMN IF NOT EXISTS location_confirmed_at TIMESTAMPTZ;

ALTER TABLE provider_service_areas
    ADD COLUMN IF NOT EXISTS area_description TEXT,
    ADD COLUMN IF NOT EXISTS radius_km NUMERIC(8, 2);

CREATE TABLE IF NOT EXISTS organization_verification_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    previous_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    decision VARCHAR(30) NOT NULL,
    review_notes TEXT,
    rejection_reason TEXT,
    requested_changes TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_organization_verification_records_org
    ON organization_verification_records (organization_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_specialized_profiles_user_category
    ON specialized_profiles (user_id, profile_category);
CREATE INDEX IF NOT EXISTS idx_profile_completion_profile_updated
    ON profile_completion_metadata (specialized_profile_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_profile_verification_pending
    ON specialized_profiles (submitted_at DESC)
    WHERE verification_status IN ('submitted', 'pending_review');
