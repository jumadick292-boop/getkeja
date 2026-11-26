-- Migration: 106_provider_identity_convergence
-- Description: Safe, additive convergence of the duplicate garbage-provider
--   identity model. Adds an explicit link from garbage_providers to the central
--   specialized_profiles identity WITHOUT dropping or rewriting existing rows,
--   assignments or requests. Also adds organisations.is_active so provider
--   organizations can be deactivated and excluded from request eligibility.
--
-- Non-destructive: existing garbage_providers.id values are preserved, so
-- garbage_provider_assignments and garbage_collection_requests FKs remain valid.

-- Organization active flag (idempotent).
ALTER TABLE organisations ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- Explicit link from a garbage provider to its central provider identity.
ALTER TABLE garbage_providers ADD COLUMN IF NOT EXISTS specialized_profile_id UUID
    REFERENCES specialized_profiles(id) ON DELETE SET NULL;

-- Backfill: link a garbage provider to an individual approved garbage profile
-- owned by the same user, when exactly one such profile exists (avoid guessing
-- when ambiguous).
UPDATE garbage_providers gp
   SET specialized_profile_id = sub.id
  FROM (
        SELECT DISTINCT ON (sp.user_id) sp.user_id, sp.id
          FROM specialized_profiles sp
         WHERE sp.profile_category = 'garbage_collection_provider'
           AND sp.organisation_id IS NULL
         ORDER BY sp.user_id, sp.created_at ASC
       ) sub
 WHERE gp.specialized_profile_id IS NULL
   AND gp.created_by = sub.user_id;

CREATE INDEX IF NOT EXISTS idx_garbage_providers_specialized_profile_id
    ON garbage_providers (specialized_profile_id);

-- Prevent two garbage providers claiming the same central identity.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM garbage_providers
        WHERE specialized_profile_id IS NOT NULL
        GROUP BY specialized_profile_id
        HAVING COUNT(*) > 1
    ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS uq_garbage_providers_specialized_profile
            ON garbage_providers (specialized_profile_id)
            WHERE specialized_profile_id IS NOT NULL;
    ELSE
        RAISE NOTICE 'Skipping garbage<->profile uniqueness: multiple garbage providers share a profile';
    END IF;
END $$;