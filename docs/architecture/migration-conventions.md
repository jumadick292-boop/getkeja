# Database Migration Conventions — GetKeja Backend

## 1. Location and tooling

- Migrations: `server/src/db/migrations/NNN_descriptive_name.sql`
- Runner: `server/src/db/migrate.ts`
- CLI: `npm run migrate` (up), `npm run migrate:status`, `npm run migrate:create <name>`
- Tracking table: `_migrations(id SERIAL PK, name VARCHAR UNIQUE, checksum VARCHAR, applied_at TIMESTAMPTZ)`

## 2. File format

- Filename: exactly three digits, underscore, slug, `.sql` (validated by regex `^(\d+)_(.+)\.sql$`).
- Each file begins with a header comment: `-- Migration: NNN_name` and `-- Description: ...`.
- SQL is executed as-is inside a single transaction per migration (`BEGIN` … `COMMIT`).
- Use `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `DROP TRIGGER IF EXISTS` / `CREATE OR REPLACE FUNCTION` patterns so files are idempotent in form (though applied migrations must never be edited).

## 3. Safety rules

- Checksum (SHA-256 of file contents) is stored at apply time; `migrate:status` reports drift if an applied file changed on disk — drift blocks further migration.
- Migrations run one at a time, each in its own transaction; failure rolls back that migration and stops.
- Never edit or renumber an applied migration. New schema changes always add a new numbered file (`Math.max(existing) + 1`, zero-padded to 3 digits).
- `083_create_house_seeker_tables.sql` is the current latest migration; it creates `house_seeker_preferences`, `saved_listings`, `saved_searches`, `listing_reports` with triggers for `updated_at`.

## 4. Status

- 81 migrations total, all applied, 0 pending, no drift (validated against the local PostgreSQL on port 5433).
