CREATE TABLE IF NOT EXISTS user_account_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    language VARCHAR(8) NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'sw')),
    theme VARCHAR(8) NOT NULL DEFAULT 'system' CHECK (theme IN ('system', 'light', 'dark')),
    currency CHAR(3) NOT NULL DEFAULT 'KES' CHECK (currency IN ('KES', 'USD', 'EUR', 'GBP')),
    timezone VARCHAR(64) NOT NULL DEFAULT 'Africa/Nairobi',
    date_format VARCHAR(16) NOT NULL DEFAULT 'dd/MM/yyyy',
    number_format VARCHAR(16) NOT NULL DEFAULT 'en-KE',
    analytics_tracking BOOLEAN NOT NULL DEFAULT TRUE,
    personalized_ads BOOLEAN NOT NULL DEFAULT FALSE,
    data_sharing BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS account_contact_change_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel VARCHAR(8) NOT NULL CHECK (channel IN ('email', 'phone')),
    target_identifier VARCHAR(255) NOT NULL,
    token_hash CHAR(64) NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 5,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_account_contact_change_user_channel
    ON account_contact_change_tokens (user_id, channel, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_account_contact_change_token_hash
    ON account_contact_change_tokens (token_hash)
    WHERE consumed_at IS NULL;
