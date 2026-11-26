-- Migration: 105_provider_profile_uniqueness
-- Description: Database-level guarantee against duplicate provider profiles for
--   the same user + category (individual) or user + category + organization.
--   The application already checks this; these indexes are defence-in-depth.
--   Guarded so a populated DB with pre-existing duplicates is not broken — the
--   index is skipped with a NOTICE and must be reconciled manually.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM specialized_profiles
        GROUP BY user_id, profile_category
        HAVING COUNT(*) > 1
    ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS uq_specialized_profiles_individual
            ON specialized_profiles (user_id, profile_category)
            WHERE organisation_id IS NULL;
    ELSE
        RAISE NOTICE 'Skipping individual uniqueness index: duplicate (user_id, profile_category) rows exist';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM specialized_profiles
        WHERE organisation_id IS NOT NULL
        GROUP BY user_id, profile_category, organisation_id
        HAVING COUNT(*) > 1
    ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS uq_specialized_profiles_org
            ON specialized_profiles (user_id, profile_category, organisation_id)
            WHERE organisation_id IS NOT NULL;
    ELSE
        RAISE NOTICE 'Skipping org uniqueness index: duplicate (user_id, profile_category, organisation_id) rows exist';
    END IF;
END $$;