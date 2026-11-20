-- Migration: 024_add_mfa_enrollment_fields
-- Description: Add MFA enrollment timestamp and last MFA verification to users table

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS mfa_enrolled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_mfa_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS mfa_enrollment_required BOOLEAN NOT NULL DEFAULT TRUE;

-- Backfill: users with mfa_enabled=true have completed enrollment
UPDATE users
SET mfa_enrolled_at = updated_at,
    mfa_enrollment_required = FALSE
WHERE mfa_enabled = TRUE;

-- Users without MFA enabled require enrollment
UPDATE users
SET mfa_enrollment_required = TRUE
WHERE mfa_enabled = FALSE;