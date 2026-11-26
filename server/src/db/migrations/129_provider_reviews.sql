-- Migration: 129_provider_reviews
-- Description: Task 13.16 — verified-service customer reviews, provider
--   responses, moderation and reporting. A review is tied to one completed
--   operational job (resource_domain + resource_id) and one provider profile;
--   one review per job enforced by a unique index. Ratings are computed from
--   published reviews only. Additive and idempotent.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'review_status') THEN
        CREATE TYPE review_status AS ENUM ('published', 'pending_moderation', 'hidden', 'removed');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS provider_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_domain TEXT NOT NULL,
    resource_id UUID NOT NULL,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    provider_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE RESTRICT,
    provider_organisation_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    overall_rating SMALLINT NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
    comment TEXT,
    quality_rating SMALLINT CHECK (quality_rating BETWEEN 1 AND 5),
    professionalism_rating SMALLINT CHECK (professionalism_rating BETWEEN 1 AND 5),
    timeliness_rating SMALLINT CHECK (timeliness_rating BETWEEN 1 AND 5),
    value_rating SMALLINT CHECK (value_rating BETWEEN 1 AND 5),
    status review_status NOT NULL DEFAULT 'published',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX uq_provider_reviews_job ON provider_reviews (resource_domain, resource_id);
CREATE INDEX IF NOT EXISTS idx_provider_reviews_provider ON provider_reviews (provider_profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_provider_reviews_customer ON provider_reviews (customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_provider_reviews_status ON provider_reviews (status);

-- One current public response per review (history preserved in events table).
CREATE TABLE IF NOT EXISTS provider_review_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES provider_reviews(id) ON DELETE CASCADE,
    responder_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    response TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX uq_provider_review_responses_review ON provider_review_responses (review_id);

-- Review reports + moderation audit trail.
CREATE TABLE IF NOT EXISTS provider_review_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES provider_reviews(id) ON DELETE CASCADE,
    reported_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL,
    details TEXT,
    status VARCHAR(24) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_provider_review_reports_review ON provider_review_reports (review_id);

CREATE TABLE IF NOT EXISTS provider_review_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES provider_reviews(id) ON DELETE CASCADE,
    previous_status review_status,
    new_status review_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_provider_review_history_review ON provider_review_status_history (review_id, created_at);

-- Permissions. (Provider dashboard access reuses the existing
-- 'provider.dashboard.read' permission; not redefined here.)
INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.reports.view', 'View Provider Reports', 'View own operational reports', 'provider', FALSE),
    ('provider.reports.view_org', 'View Organization Reports', 'View organization-wide reports', 'provider', FALSE),
    ('provider.reviews.view', 'View Provider Reviews', 'View reviews about own jobs', 'provider', FALSE),
    ('provider.reviews.respond', 'Respond to Reviews', 'Respond to customer reviews', 'provider', FALSE),
    ('provider.complaints.view', 'View Provider Complaints', 'View complaints about own jobs', 'provider', FALSE),
    ('provider.complaints.respond', 'Respond to Complaints', 'Respond and record corrective actions', 'provider', FALSE),
    ('review.moderate', 'Moderate Reviews', 'Moderate and audit reviews', 'platform', FALSE),
    ('complaint.manage', 'Manage Complaints', 'Administer complaint cases', 'platform', FALSE)
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('service_provider')
   AND p.id IN (
     'provider.reports.view', 'provider.reports.view_org',
     'provider.reviews.view', 'provider.reviews.respond',
     'provider.complaints.view', 'provider.complaints.respond'
   )
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('platform_admin', 'super_admin')
   AND p.id IN ('review.moderate', 'complaint.manage')
ON CONFLICT (role_id, permission_id) DO NOTHING;