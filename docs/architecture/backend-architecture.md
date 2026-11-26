# Backend Architecture — GetKeja

**Repository:** `server/`  
**Stack:** Node.js ≥22, Express 5, TypeScript 5.8 (ESM), PostgreSQL via raw `pg` queries, Redis via `ioredis`, job queue via `pg-boss`, validation via `zod`, logging via `pino`, tests via `vitest` + `supertest`.

## 1. Actual structure (adopted)

The target structure in the House Seeker requirements is used as a reference, not a mandate. The existing codebase is already a modular monolith organized by feature, so paths were kept as-is to avoid breaking changes. Justified deviations are listed in section 4.

```
server/src/
  app.ts                 — Express app factory; mounts routers + health/ready
  main.ts                — Process entry: env, logger, DB, Redis, workers, shutdown
  config/
    env.ts               — Zod-validated environment (single source of truth)
    env.test.ts          — Test env overrides
  db/
    pool.ts              — Shared pg Pool (singleton proxy)
    redis.ts             — Shared Redis client (lazy connect)
    tx.ts                — Shared transaction helper (transaction<T>)
    migrate.ts           — Migration runner (checksum-verified, transactional)
    migrate.cli.ts       — npm run migrate {up|status|create}
    migrations/          — 001..083 SQL migrations + _migrations tracking table
    migrationTypes.ts
  middleware/
    error-handler.ts     — JSON error handler, maps HttpError -> status/code
    rate-limit.ts        — Redis-backed rate limiters keyed by identifier
    security.ts          — CORS + CSRF middleware
    validate.ts          — Zod body/query/params validation
  shared/
    errors.ts            — HttpError hierarchy (400/401/403/404/409)
    logger.ts            — Pino logger helper
  types/
    express.d.ts         — Express Request augmentation
  jobs/
    boss.ts              — pg-boss instance
    register-workers.ts  — Worker registrations (notification outbox, etc.)
  modules/
    auth/                — Authentication, sessions, MFA, registration,
                          authorization, notifications, organisations
    house-seeker/        — House Seeker experience (discovery, saved homes,
                          saved searches, enquiries, visits, conversations,
                          applications, proposals, journey)
    landlord/            — Landlord-side enquiries, proposals, applications
    listings/            — Published listing discovery (nearby, directions)
    location/            — Location sharing, provider discovery
    profile/             — Profiles, images, documents, Google Places, Cloudinary
  routes/                — Not present as a separate directory; each module
                          exports its own Express Router (see deviation #2)
```

Module file conventions (existing, reused):
- `*.routes.ts` — Express Router definition, route registration, validation middleware
- `*.controller.ts` — HTTP request/response handling only; no SQL
- `*.repository.ts` — Raw SQL through the shared `pool` (or `tx.transaction`)
- `*.schema.ts` — Zod request/response schemas + inferred TypeScript types
- `*.service.ts` — Business rules where present (auth, profile, listings)
- `*.test.ts` — Vitest tests colocated with the module

## 2. Shared infrastructure (single instances, no duplication)

- **Database connection:** one `pg` Pool in `db/pool.ts`, exported as `pool`, initialized in `main.ts` (`initializeDatabase`), health-checked at `/ready`.
- **Transactions:** `db/tx.ts` exports `transaction<T>(work)` — BEGIN/COMMIT/ROLLBACK around a `PoolClient`. All multi-statement work must use it; controllers must not open transactions.
- **Cache:** one Redis client in `db/redis.ts` (`getRedisClient`), used for rate limiting, sessions, outbox, caching.
- **Authentication:** single auth system in `modules/auth` (JWT access tokens, refresh tokens, sessions, MFA, email/phone/Google providers). `requireAuth` middleware (`auth.middleware.ts`) populates `req.user`/`req.session`.
- **Notifications:** one outbox-backed notification service (`modules/auth/notification.service.ts`, `notification.worker.ts`, `notification_templates/notifications/notification_preferences/notification_delivery_attempts/notification_outbox tables`).
- **Jobs:** `pg-boss` workers in `jobs/boss.ts`; registration in `jobs/register-workers.ts`.
- **Storage/media:** Cloudinary (`profile/cloudinary.service.ts`) and AWS S3 private bucket (`@aws-sdk/client-s3`) — no duplicate media abstractions.
- **Maps/location:** Google Maps server + Routes keys in `config/env.ts`; geocoding via `modules/profile/google-places.service.ts`.

## 3. API routing and versioning

- Routers are created by each module (`createXRouter()`) and mounted in `app.ts`.
- Mount paths: `/api/v1/<feature>` (canonical) plus `/api/<feature>` compatibility mounts for `auth` and `profile`.
- House Seeker: mounted at `/api/v1/house-seeker` (`createHouseSeekerRouter`, all routes require `requireAuth`).
- Root: `GET /health`, `GET /ready` (DB + Redis ping).
- Error envelope: `{ success: false, message, code }`; success envelope documented in `API.md` (`{ success, message, data }`).
- Full endpoint reference: `server/API.md` (auth) and `server/openapi.yaml`.

## 4. Deviations from the target structure (justified)

| Target | Existing | Reason kept |
|---|---|---|
| `modules/authentication/` | `modules/auth/` | Established name across routes, imports, tests; renaming breaks the app for no functional gain. |
| `modules/users/` + `modules/profiles/` | `modules/profile/` | User and profile concerns are already in one coherent module; no split justified. |
| `modules/saved-homes/`, `saved-searches/`, `property-comparison/`, `rental-proposals/`, … | Not separate modules | These concerns are implemented inside `modules/house-seeker` (saved-listings, saved-searches, proposals, applications share the house-seeker security context). Creating empty separate modules would violate "no empty boilerplate". They can be split in Phase 2 only when ownership crosses module boundaries. |
| `routes/v1/` directory | None | Route definition lives beside each module; `app.ts` mounts them. Central `routes/v1` adds indirection without value. |
| `common/` directory | `shared/` + middleware at `src/middleware` | Same purpose, fewer layers. |
| `infrastructure/` directory | `db/`, `jobs/` at `src/` | Equivalent concern grouping at the top level. |

## 5. Authorization model

- Resource-scoped: every House Seeker repository method filters by `user_id` (e.g. `prospective_renter_id = $1`, `user_id = $1`) and raises `404`/`403` for foreign resources (IDOR protection verified by tests).
- House Seeker routes all run under `requireAuth`; landlord modules have their own role-scoped guards. Existing landlord and tenant functionality is preserved.

## 6. Conventions

- No ORM: raw parameterized SQL via `pg`, query building with a local `$n` binder.
- No SQL in controllers: controllers call repositories only.
- Validation at the route boundary via `zod` schemas (`validate()` middleware); `strict()` objects to reject unknown fields.
- Database migrations: numbered `NNN_descriptive_name.sql`, checksum-verified, applied transactionally per migration (`db/migrate.ts`), tracked in `_migrations`. See `docs/architecture/migration-conventions.md`.
