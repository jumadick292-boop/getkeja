-- Migration: 009_create_google_identities_table
-- Description: Create google_identities table for Google OAuth linking

CREATE TABLE IF NOT EXISTS google_identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    login_identity_id UUID NOT NULL REFERENCES user_login_identities(id) ON DELETE CASCADE,
    google_subject VARCHAR(255) NOT NULL UNIQUE, -- Google 'sub' claim
    email VARCHAR(255) NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    name VARCHAR(255),
    given_name VARCHAR(100),
    family_name VARCHAR(100),
    picture VARCHAR(500),
    locale VARCHAR(10),
    raw_profile JSONB, -- full Google profile for future use
    linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_google_identities_user_id ON google_identities (user_id);
CREATE INDEX IF NOT EXISTS idx_google_identities_login_identity ON google_identities (login_identity_id);
CREATE INDEX IF NOT EXISTS idx_google_identities_google_subject ON google_identities (google_subject);