-- Track whether a restricted account state was set by its owner or by an administrator.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS account_status_source VARCHAR(16),
  ADD COLUMN IF NOT EXISTS personal_data_purged_at TIMESTAMPTZ,
  ADD CONSTRAINT users_account_status_source_check
    CHECK (account_status_source IS NULL OR account_status_source IN ('user', 'admin'));

-- Existing restricted accounts are treated as admin-managed because their original
-- source cannot be established safely from current records.
UPDATE users
SET account_status_source = CASE
  WHEN (
    SELECT event.event_type
    FROM security_events event
    WHERE event.user_id = users.id
      AND event.event_type IN (
        'account_paused', 'account_deletion_requested', 'admin_account_status_changed'
      )
    ORDER BY event.created_at DESC
    LIMIT 1
  ) = CASE
      WHEN account_status = 'deactivated' THEN 'account_paused'
      ELSE 'account_deletion_requested'
    END THEN 'user'
  ELSE 'admin'
END
WHERE account_status IN ('deactivated', 'deleted')
  AND account_status_source IS NULL;

CREATE TABLE IF NOT EXISTS account_restore_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  restore_type VARCHAR(24) NOT NULL CHECK (restore_type IN ('reactivate', 'restore_deleted')),
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_account_restore_tokens_user
  ON account_restore_tokens (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_account_restore_tokens_expiry
  ON account_restore_tokens (expires_at) WHERE used_at IS NULL;
