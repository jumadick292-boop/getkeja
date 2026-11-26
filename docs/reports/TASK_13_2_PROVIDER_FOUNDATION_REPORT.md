# Task 13.2 — Provider Domain Foundation Report

## 1. Files and modules changed

**New (backend)**
- `server/src/modules/provider/provider.types.ts`
- `server/src/modules/provider/provider.schemas.ts`
- `server/src/modules/provider/provider.authorization.ts`
- `server/src/modules/provider/provider.repository.ts`
- `server/src/modules/provider/provider.service.ts`
- `server/src/modules/provider/provider.controller.ts`
- `server/src/modules/provider/provider.routes.ts`
- `server/src/modules/provider/provider.test.ts` (26 integration tests)
- `server/src/modules/service-requests/service-requests.lifecycle.ts`
- `server/src/db/migrations/104_seed_provider_foundation_permissions.sql`

**Modified (backend)**
- `server/src/app.ts` — mount `/api/v1/provider`.
- `server/src/modules/tenant/tenant.schema.ts` — `tenantRequestListQuerySchema`.
- `server/src/modules/tenant/tenant.repository.ts` — paginated list queries (moving/laundry/garbage).
- `server/src/modules/tenant/tenant.controller.ts` — `getTenantMovingRequests`, `getTenantLaundryRequests`, fixed+paged `getTenantGarbageRequests`.
- `server/src/modules/tenant/tenant.routes.ts` — GET routes + query validation.
- `server/src/modules/auth/transactional-outbox.service.ts` — classify request lifecycle events as critical.
- `server/openapi.yaml` — provider paths + tenant list GETs + schemas.

**New (Flutter)**
- `Mobile/lib/features/provider/domain/entities/provider_dashboard.dart`
- `Mobile/lib/features/provider/domain/repositories/provider_repository.dart`
- `Mobile/lib/features/provider/data/datasources/provider_remote_datasource.dart`
- `Mobile/lib/features/provider/data/repositories/provider_repository_impl.dart`
- `Mobile/lib/features/provider/presentation/state/provider_state.dart`
- `Mobile/lib/features/provider/presentation/pages/provider_dashboard_page.dart`

**Modified (Flutter)**
- `Mobile/lib/app/router/app_router.dart` — guarded `/provider/dashboard` route.

**Docs**
- `docs/architecture/service-provider-domain-foundation.md`
- `docs/reports/TASK_13_2_PROVIDER_FOUNDATION_REPORT.md`

## 2. Endpoints (new / reused)

New: `GET /api/v1/provider/dashboard`, `GET /api/v1/provider/requests`,
`GET /api/v1/provider/requests/:id`, `POST /api/v1/provider/requests/:id/respond`,
`GET /api/v1/provider/discovery`, `GET /api/v1/tenant/moving-requests`,
`GET /api/v1/tenant/laundry-requests`.
Reused/fixed: `GET /api/v1/tenant/garbage-requests` (was 500 due to non-existent
columns; now paginated), existing POST/DELETE tenant endpoints, existing
Haversine `provider-discovery.repository`.

## 3. Provider identity & organization context

Single identity. `resolveProviderContext` derives individual profiles
(owned `specialized_profiles`), organization profiles (via active
`organisation_members`), and garbage providers (`created_by`/`organisation_id`).
Active org is validated against memberships (never the first assumed). A user may
have multiple profiles/memberships.

## 4. Provider authorization rules

Resource-scoped, not role-name based. Assigned ⇒ full detail; discoverable
(unassigned + submitted + approved category + service-area match) ⇒ masked.
Membership alone never grants request access. Revoked membership / non-approved
profile removes access. No access by id alone (IDOR-safe). Caretakers/landlords/
PMs without a provider profile are denied.

## 5. Tenant request-list implementation

All three lists scoped to the authenticated tenant (moving/laundry by
`tenant_id`, garbage by the tenant's active unit), with `status`/`limit`/`offset`,
stable `created_at DESC` sort, `LEFT JOIN` provider name (no N+1), and
`{ success, data, pagination:{limit,offset,total} }`. Cross-tenant isolation and
empty results verified.

## 6. Provider discovery

Coordinate mode reuses the Haversine repo; text mode matches active service areas
by county/city. Only public fields returned (no coordinates/contact/residential
data). Invalid coordinate input → 400.

## 7. Lifecycle transitions implemented

moving/laundry: provider `submitted|pending_confirmation → accepted|declined`;
customer `→ cancelled`. garbage: provider `pending → assigned|cancelled`;
customer `pending → cancelled`. Concurrency-guarded; invalid/unauthorized
transitions rejected (409/403). History via existing DB triggers (`updated_by`
set).

## 8. Outbox events & atomicity

`moving_request.created`, `garbage_request.created`, `laundry_request.created`,
`service_request.accepted`, `service_request.declined` classified **critical**;
persisted in the same transaction as the state change (rollback on failure).
Stable idempotency keys; `ON CONFLICT DO NOTHING` prevents duplicates; payloads
carry no private data.

## 9. Dashboard

Provider-scoped counts (new eligible, assigned, pending responses, accepted/
upcoming/active/completed/cancelled). `pendingQuotations = 0`. Org scope via
validated `organizationId`. Non-provider → 403.

## 10. Database changes & migration checksums

Only `104_seed_provider_foundation_permissions.sql` (additive, idempotent:
`ON CONFLICT DO NOTHING`, permission inserts + grants to existing provider
roles). No request/profile/area schema changes. Applied via the standard runner
(`migrate up`); status shows it applied; checksum verification is enforced by the
runner. Safe on fresh and existing DBs (idempotent).

## 11. Garbage-provider convergence decision

Deferred to Task 13.3. `garbage_providers` remains authoritative for garbage;
`specialized_profiles` for moving/laundry. Foundation maps garbage users via
`created_by`/`organisation_id`. No new tables, no destructive change.

## 12. OpenAPI changes

Added 5 provider paths + 2 tenant list GETs, `Pagination`, `ProviderDashboard`,
`ProviderRequest`, `ProviderDiscoveryResult` schemas. YAML validated.

## 13. Flutter changes

New `provider` feature (datasource → repository → Riverpod Notifier → real
API-backed dashboard page) using the shared Dio client and `/api/v1` paths;
guarded `/provider/dashboard` route. No second Dio client; no hardcoded
org/provider ids.

## 14. Test totals

- Backend: `provider.test.ts` 26/26 pass; full suite **551/551 pass (37 files)**.
- Flutter: **196/196 pass** (`--dart-define=API_BASE_URL=http://localhost:4000`).

## 15. Analysis results

- `tsc --noEmit`: clean.
- `flutter analyze`: no errors; only pre-existing infos/warnings in unrelated
  files (provider files contribute 2 codebase-wide infos).

## 16. Remaining limitations

Quotation/negotiation, scheduling, in-progress/completion transitions, exclusive
assignment on accept (discovery intentionally does not auto-assign), garbage
recurring/provider-change/missed-collection, payouts/commission, full provider
Flutter screens, route optimization/live tracking — all deferred to later tasks.

## 17. Recommended next task

Task 13.3 — Provider Profiles, Organizations and Staff Management (includes the
garbage-provider convergence migration and staff/role management).