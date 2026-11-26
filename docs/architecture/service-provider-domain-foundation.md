# Service Provider Domain Foundation (Task 13.2)

This document describes the shared provider foundation implemented in Task 13.2:
the provider API namespace, provider context resolution, request eligibility and
authorization, discovery, the shared lifecycle, outbox behaviour, the dashboard,
and the garbage-provider model decision. It is an accurate description of the
**implemented** code, not a plan.

## 1. Provider API namespace

All provider endpoints are mounted at `/api/v1/provider` (`server/src/app.ts`)
and require authentication (`requireAuth`). Authorization is resource-scoped
inside the service layer, not role-name based.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/v1/provider/dashboard` | Provider-scoped counts |
| GET | `/api/v1/provider/requests` | Inbox (eligible + assigned) |
| GET | `/api/v1/provider/requests/:requestId` | Detail (masked unless assigned) |
| POST | `/api/v1/provider/requests/:requestId/respond` | Accept/decline (validated transition) |
| GET | `/api/v1/provider/discovery` | Discover approved providers |

Tenant list endpoints added/completed under `/api/v1/tenant`:
`GET /moving-requests`, `GET /garbage-requests` (fixed + paginated),
`GET /laundry-requests`. All support `status`, `limit`, `offset` and return
`{ success, data, pagination }`.

## 2. Provider context resolution

`resolveProviderContext(userId, organizationId?)` (`provider.authorization.ts`)
derives an effective provider context from the central identity:

- **Individual**: `specialized_profiles` owned by the user
  (`user_id = userId`) with a provider category, `verification_status =
  'approved'`, and operating status active (or no extension).
- **Organization**: approved+active `specialized_profiles` reached through the
  user's **active** organization memberships (`organisation_members.status =
  'active'`). The active organization is validated against the user's
  memberships — the first membership is never assumed.
- **Garbage**: active `garbage_providers` reachable via
  `organisation_id ∈ active orgs` OR `created_by = userId`.

A user may hold multiple profiles and memberships. `isProvider` is true only
when at least one approved profile or reachable garbage provider exists.

## 3. Request eligibility & authorization

`canAccessProviderRequest(context, requestId)`:

- **Assigned** (full detail): moving/laundry `provider_id ∈
  effectiveProfileIds`; garbage `garbage_provider_id ∈ garbageProviderIds`.
- **Discoverable** (masked): moving/laundry request is unassigned
  (`provider_id IS NULL`), `status = 'submitted'`, and the provider has an
  approved profile of the matching category with an active service area
  matching the property county/city.
- Otherwise denied.

Organization membership alone never grants request access; it only contributes
profiles. Caretakers/landlords/property managers without a provider profile are
denied. Revoked membership or a non-approved profile removes access. No access
is granted by request id alone (IDOR-safe).

## 4. Discovery

`GET /api/v1/provider/discovery`:

- Coordinate mode reuses the existing Haversine repository
  (`location/provider-discovery.repository.ts`).
- Text fallback (`county`/`city`) matches active `provider_service_areas`.
- Returns only public fields (`profileId`, `profileCategory`, `businessName`,
  `description`, `distanceKm`, `city`, `county`, `areaDescription`). No raw
  coordinates, contact details, or residential addresses are exposed.
- Requires coordinates (lat+lng together) or a county/city; invalid input →
  400.

## 5. Lifecycle foundation

`service-requests/service-requests.lifecycle.ts` centralises transition rules
without collapsing the three domain enums. Each domain keeps its own status enum
and status-history table/trigger; the module sets `updated_by` so the existing
trigger records who changed the status (no duplicate history infrastructure).

Implemented transitions (foundation subset):

| Domain | Actor | From → To |
|--------|-------|-----------|
| moving/laundry | provider | submitted/pending_confirmation → accepted / declined |
| moving/laundry | customer | submitted/pending_confirmation → cancelled |
| garbage | provider | pending → assigned (accept) / cancelled (decline) |
| garbage | customer | pending → cancelled |

Updates are transaction-safe and concurrency-guarded (`WHERE status =
expectedFrom`); a concurrent change yields 409. Invalid/unauthorized
transitions are rejected before any write.

### Status mapping (existing enums → shared lifecycle)

- moving/laundry: `submitted, pending_confirmation, accepted, scheduled,
  in_progress, completed, declined, cancelled` (DB enums unchanged).
- garbage: `pending, assigned, in_progress, completed, cancelled`. Garbage has
  no `declined`; a provider decline maps to `cancelled` with a reason.

## 6. Outbox & atomicity

Request creation events (`moving_request.created`, `garbage_request.created`,
`laundry_request.created`) and provider responses
(`service_request.accepted`, `service_request.declined`) are classified
**critical** in `transactional-outbox.service.ts` and persisted with
`enqueueOutboxEventTransactional` inside the same DB transaction as the state
change. If the outbox insert fails, the business transaction rolls back.
Idempotency keys are stable (`service_request.accepted:<requestId>`);
`notification_outbox` enforces uniqueness via `ON CONFLICT (idempotency_key) DO
NOTHING`. Payloads contain no private provider/customer data beyond the request
id, service type, status and action.

## 7. Dashboard

`GET /api/v1/provider/dashboard` returns provider-scoped counts computed from
records the provider may access: new eligible (discoverable) requests, assigned
requests, pending responses, accepted/upcoming/active/completed/cancelled jobs.
`pendingQuotations` is `0` (quotations are a later task). Organization scope is
honoured via `organizationId` (validated against memberships). Non-providers
receive 403.

## 8. Garbage-provider model convergence — decision

Two models coexist: `garbage_providers` (authoritative for existing garbage CRUD,
assignments, and the Flutter garbage feature) and `specialized_profiles`
(authoritative for moving/laundry). **Convergence is deferred** to a dedicated
migration task (13.3) because it requires a data backfill and FK migration that
would be risky to perform here. The foundation maps garbage-provider users via
`garbage_providers.created_by` / `organisation_id` and introduces **no new
tables** and no destructive change. Migration `104_seed_provider_foundation_
permissions.sql` only seeds additive `provider.*` permissions (idempotent).

## 9. Database changes

- `104_seed_provider_foundation_permissions.sql` — additive, idempotent
  permission seed + grants to existing provider roles. No schema changes to
  request/profile/area tables. Status history reuses existing triggers.

## 10. Known gaps intentionally deferred

- Quotation/negotiation, scheduling, in-progress/completion transitions.
- Exclusive assignment on accept (discovery intentionally does not auto-assign).
- Garbage recurring generation, provider-change, missed-collection.
- Payouts/commission, provider-specific Paybills (central collections remain).
- Full provider Flutter screens (only a real dashboard foundation page exists).
- Route optimization / live tracking (blueprint out of scope).