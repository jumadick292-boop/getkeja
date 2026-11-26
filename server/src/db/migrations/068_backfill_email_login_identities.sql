-- Restore email/password identities for accounts created before login identities
-- became the source of truth. Preserve the existing password and verification state.
INSERT INTO user_login_identities (
  user_id,
  provider,
  identifier,
  password_hash,
  verified_at,
  is_primary
)
SELECT
  u.id,
  'email',
  lower(trim(u.email)),
  u.password_hash,
  CASE WHEN u.email_verified THEN u.updated_at ELSE NULL END,
  TRUE
FROM users u
WHERE u.email IS NOT NULL
  AND u.password_hash IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM user_login_identities li
    WHERE li.provider = 'email'
      AND lower(trim(li.identifier)) = lower(trim(u.email))
  );

UPDATE user_login_identities li
SET password_hash = u.password_hash,
    verified_at = CASE
      WHEN u.email_verified THEN COALESCE(li.verified_at, u.updated_at)
      ELSE li.verified_at
    END,
    updated_at = NOW()
FROM users u
WHERE li.user_id = u.id
  AND li.provider = 'email'
  AND li.password_hash IS NULL
  AND u.password_hash IS NOT NULL;
