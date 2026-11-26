# API Conventions — GetKeja Backend

Canonical reference documents: `server/API.md` (auth endpoint reference) and
`server/openapi.yaml` (OpenAPI spec). This file summarizes cross-cutting rules.

## 1. Versioning and base paths

- Canonical: `/api/v1/<feature>` (e.g. `/api/v1/house-seeker`, `/api/v1/listings`).
- Compatibility mounts: `/api/auth` and `/api/profile` remain mounted alongside `/api/v1/…` for existing clients.
- Version prefix lives in the mount path, not the hostname. No `/v2` exists yet.

## 2. Routers and mounting

- Each feature module exports `createXRouter()` returning an Express `Router`.
- All routers are mounted in a single place: `server/src/app.ts`.
- There is no separate `routes/v1/` directory; route definition is colocated with the module.

## 3. Request validation

- `zod` schemas define every request body, query, and params shape (`.strict()` to reject unknown fields).
- `middleware/validate.ts`: `validate(schema, source)` middleware — 400 on failure with a `field: message` detail string.
- Parsed values are attached to `req.body` / `req.query` / `req.params` so controllers receive typed data.

## 4. Error handling

- `shared/errors.ts`: `HttpError(message, status)` plus `ConflictError` (409), `UnauthorizedError` (401), `ForbiddenError` (403), `NotFoundError` (404), `ValidationError` (400).
- `middleware/error-handler.ts`: centralized JSON error handler — always `{ success: false, message, code }`; codes: `NOT_FOUND`, `FORBIDDEN`, `UNAUTHORIZED`, `CONFLICT`, `VALIDATION_ERROR`, `RATE_LIMITED`, `INTERNAL_ERROR`, `PAYLOAD_TOO_LARGE`, `INVALID_JSON`.
- Controllers never catch operational errors; they `next(error)` or throw, and the handler maps `HttpError.status` to the HTTP status.

## 5. Responses

- Success envelope (documented in API.md): `{ success: true, message, data }`.
- Failure envelope: `{ success: false, message, code }`.
- House Seeker discovery responses: `{ items, total, limit, offset }` for lists; single objects for details.

## 6. Authentication

- Bearer access token (`Authorization: Bearer <token>`) or `x-access-token` header.
- `modules/auth/auth.middleware.ts#requireAuth` validates the token via the session service and sets `req.user` / `req.session`.
- All House Seeker routes are wrapped in `requireAuth`.
- Resource-scoped authorization: repository methods filter by `user_id` and return 404/403 for foreign resources (IDOR tested).

## 7. What to avoid (enforced by code review)

- No SQL in controllers (controllers call repositories only).
- No ORM (raw `pg` queries only).
- No duplicate property/listing models (House Seeker reads `properties`/`property_listings`/`units`).
- No new microservices (single modular monolith, one database).
