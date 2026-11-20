-- Migration: 019_add_account_status
-- Description: Add explicit authentication lifecycle state and deletion marker

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS account_status VARCHAR(32) NOT NULL DEFAULT 'pending_verification',
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

UPDATE users
SET account_status = CASE
  WHEN deleted_at IS NOT NULL THEN 'deleted'
  WHEN is_deactivated THEN 'deactivated'
  WHEN is_suspended THEN 'suspended'
  WHEN is_locked THEN 'locked'
  WHEN is_active AND (email_verified OR phone_verified) THEN 'active'
  ELSE 'pending_verification'
END;

ALTER TABLE users
  ADD CONSTRAINT users_account_status_check
  CHECK (account_status IN (
    'pending_verification',
    'active',
    'suspended',
    'locked',
    'deactivated',
    'deleted'
  ));

CREATE INDEX IF NOT EXISTS idx_users_account_status ON users(account_status);
