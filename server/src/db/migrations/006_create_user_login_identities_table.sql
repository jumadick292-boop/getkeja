-- Migration: 006_create_user_login_identities_table
-- Description: Create user_login_identities table for managing multiple authentication methods per user

CREATE TABLE IF NOT EXISTS user_login_identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(20) NOT NULL, -- 'email', 'phone', 'google'
    identifier VARCHAR(255) NOT NULL, -- email address, phone number (E.164), or Google subject
    password_hash VARCHAR(255), -- nullable for passwordless methods
    verified_at TIMESTAMPTZ,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    metadata JSONB, -- provider-specific data (e.g., Google profile info)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, identifier)
);

CREATE INDEX IF NOT EXISTS idx_user_login_identities_user_id ON user_login_identities (user_id);
CREATE INDEX IF NOT EXISTS idx_user_login_identities_provider_identifier ON user_login_identities (provider, identifier);
CREATE INDEX IF NOT EXISTS idx_user_login_identities_user_provider ON user_login_identities (user_id, provider);