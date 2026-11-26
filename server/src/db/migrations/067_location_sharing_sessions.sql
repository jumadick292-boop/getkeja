-- Purpose-bound, revocable location sharing for two participants of a site visit.
-- Only the latest coordinate is retained; sharing history contains no coordinates.
CREATE TABLE IF NOT EXISTS location_sharing_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_visit_id UUID NOT NULL REFERENCES site_visits(id) ON DELETE CASCADE,
    sharer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    accuracy_meters DECIMAL(10, 2),
    location_updated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_location_share_distinct_users CHECK (sharer_user_id <> recipient_user_id),
    CONSTRAINT chk_location_share_coordinate_pair CHECK ((latitude IS NULL) = (longitude IS NULL))
);

CREATE INDEX IF NOT EXISTS idx_location_share_owner_active
    ON location_sharing_sessions (sharer_user_id, created_at DESC)
    WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_location_share_recipient_active
    ON location_sharing_sessions (recipient_user_id, expires_at)
    WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_location_share_expiry
    ON location_sharing_sessions (expires_at)
    WHERE revoked_at IS NULL;
