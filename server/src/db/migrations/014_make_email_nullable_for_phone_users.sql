-- Migration: 014_make_email_nullable_for_phone_users
-- Description: Make email column nullable to support phone-only registration

ALTER TABLE users
  ALTER COLUMN email DROP NOT NULL;

-- Add unique constraint on email where email is not null
CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique_not_null ON users (lower(email)) WHERE email IS NOT NULL;