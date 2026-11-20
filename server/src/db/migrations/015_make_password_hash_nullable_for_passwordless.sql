-- Migration: 015_make_password_hash_nullable_for_passwordless
-- Description: Make password_hash column nullable to support passwordless registration

ALTER TABLE users
  ALTER COLUMN password_hash DROP NOT NULL;