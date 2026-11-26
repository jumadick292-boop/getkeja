# GetKeja Service Provider Platform — Architecture Audit and Implementation Blueprint (Task 13.1)

**Repository:** `get-keja-repo`
**Backend:** `server/` — Node.js, Express 5, TypeScript (ESM), PostgreSQL, Redis
**Flutter app:** `Mobile/` — Flutter (Dart), Riverpod, Dio, GoRouter
**Blueprint source:** `server/System_Design_Blueprint_Plain_Black.pdf`
**Domains in scope:** Moving services, Garbage collection, Laundry services
**Status:** Audit complete. One foundational defect fixed (see §10). Provider-facing platform not yet implemented.

> **Accuracy note.** This revision supersedes the previous draft of this file. The prior draft incorrectly claimed that tenant-facing moving/garbage/laundry endpoints did not exist and returned 404. Verified reading of `server/src/modules/tenant/tenant.routes.ts` and `server/src/app.ts` shows those endpoints **do exist**. The real defect was a Flutter client base-path bug (missing `/api/v1`), now fixed. Every claim below is backed by `file:line` evidence gathered from the actual repository.

---

## 1. Executive Summary

- **Tenant (customer) request submission for all three domains is implemented** on the backend under the existing `tenant` module (`POST /api/v1/tenant/{moving,garbage,laundry}-requests`, plus `DELETE .../:id` to cancel). Garbage additionally has `GET /garbage-requests`. Moving and laundry have **no `GET` list endpoint** (gap).
- **Provider identity, profiles, service areas, saved locations, verification** are implemented in the `profile` module and DB (`specialized_profiles`, `provider_profile_extensions`, `laundry_provider_services`, `provider_service_areas`, `saved_locations`, `profile_verification_*`).
- **Provider discovery by distance exists as a repository function** (Haversine query in `location/provider-discovery.repository.ts`) but is **not exposed over HTTP** (no route/controller).
- **The entire provider-facing platform is missing**: no `/api/v1/provider` namespace, no request inbox, no quotations/negotiation, no job assignment/status/completion, no provider dashboard, no earnings/payouts, no provider Flutter screens.
- **Financial integration for providers is absent.** Payments handle tenant→landlord rent only. No payout/commission tables or services exist (only a seeded `financial.approve_payouts` permission and a non-wired Zod schema).
- **Workers are not pg-boss.** `jobs/boss.ts` and `jobs/register-workers.ts` are empty; workers use `setInterval` loops.
- **Blueprint scope vs. reality:** the System Design Blueprint covers **moving + garbage only**. **Laundry is not in the blueprint** — it is a repository extension. The blueprint also **explicitly excludes** fleet management, route optimization, driver management, and automated collection logistics (§Out of Scope). The roadmap respects these exclusions.

**Recommended next task:** Task 13.2 — Shared Provider Domain Foundation and Authorization (see roadmap).

---

## 2. Actual Current Implementation Inventory

### 2.1 Backend modules (`server/src/modules/`)

| Module | State | Provider relevance |
|--------|-------|--------------------|
| `auth` | Full (auth, MFA, authorization, organization service) | Identity, RBAC, org membership |
| `profile` | Full | Provider profiles, extensions, laundry services, service areas, saved locations, verification |
| `location` | Partial | `provider-discovery.repository.ts` (distance query) + `location-sharing` (no continuous tracking) |
| `tenant` | Full for create/cancel | Tenant-facing moving/garbage/laundry request submission |
| `landlord` | Full | Garbage provider CRUD, property↔provider assignments, landlord collection requests |
| `payments` | Full (tenant rent) | Reference pattern; no provider payouts |
| `messaging` | Full (contextual conversations) | Reusable for request-scoped chat |
| `house-seeker`, `listings`, `rental-applications`, `site-visits` | Full | Adjacent domains |
| `service-requests` | **Schema only** (`service-requests.schema.ts`, no controller/routes/repo) | Placeholder for future unified module |
| `moving`, `garbage`, `laundry` (as standalone modules) | **Do not exist** | Logic lives in `tenant` + `landlord` |

### 2.2 Tenant-facing endpoints (verified) — `tenant.routes.ts` + `app.ts:81`

Mounted at `/api/v1/tenant` (`app.ts:81`), all behind `requireAuth` (`tenant.routes.ts:38`).

| Method | Path | Handler | Notes |
|--------|------|---------|-------|
| GET | `/garbage-requests` | `getTenantGarbageRequests` | List exists |
| POST | `/garbage-requests` | `createTenantGarbageRequest` | Resolves provider via `garbage_provider_assignments`; emits `garbage_request.created` |
| DELETE | `/garbage-requests/:requestId` | `cancelTenantGarbageRequest` | Owner check via `created_by` |
| POST | `/moving-requests` | `createTenantMovingRequest` | Optional `providerId` (must be `moving_service_provider`); status `submitted`/`pending_confirmation`; emits `moving_request.created` |
| DELETE | `/moving-requests/:requestId` | `cancelTenantMovingRequest` | Owner check via `tenant_id` |
| POST | `/laundry-requests` | `createTenantLaundryRequest` | **Requires `providerId`** (`laundry_service_provider`); emits `laundry_request.created` |
| DELETE | `/laundry-requests/:requestId` | `cancelTenantLaundryRequest` | Owner check via `tenant_id` |
| — | **GET `/moving-requests`** | **MISSING** | Flutter list screen calls this → 404 |
| — | **GET `/laundry-requests`** | **MISSING** | Flutter list screen calls this → 404 |

Evidence: `tenant.routes.ts:80-115`, `tenant.controller.ts:467-822`, `tenant.schema.ts:43-81`.

### 2.3 Provider profiles & discovery

- **Profile module** (`profile.routes.ts`): CRUD for `specialized_profiles`, provider extensions, laundry services, service areas, saved locations, verification records, completion. Categories include `moving_service_provider`, `garbage_collection_provider`, `laundry_service_provider` (`profile.schema.ts:9-20`).
- **Provider extension** fields: `serviceTypes[]`, `serviceDescription`, `operatingStatus`, `registrationNumber`, `taxId`, `businessHours`, `available247`, `emergencyService`, `insuranceInfo`, `certifications[]`, booking contacts (`profile.schema.ts:159-172`).
- **Laundry services**: boolean offering flags + `pickupDeliveryAreas[]` (`profile.schema.ts:174-188`).
- **Service areas** (`provider_service_areas`, migration 059): country/county/city/neighbourhood + lat/lng + `radius_km` + `is_active`.
- **Saved locations** (`saved_locations`, migration 058): `personal_residential`, `business_office`, `provider_operating`, `service_area`, `property_location`.
- **Discovery**: `provider-discovery.repository.ts` runs a Haversine query filtering `verification_status='approved'` and `radius_km`, returning nearest match per provider. **Not wired to any HTTP route** (no controller/route references it).

### 2.4 Garbage (landlord surface) — `landlord.routes.ts:316-338`

CRUD for `/garbage-providers`, `/garbage-assignments`, `/garbage-collection-requests` (controller `landlord.controller.ts:785-1008`). Assignments carry `assignment_type`, `frequency` (daily/weekly/biweekly/monthly/on_call), `day_of_week`, `time_slot`, `effective_from/to`.

### 2.5 Database (migrations)

| Migration | Tables / enums |
|-----------|----------------|
| 055 | `specialized_profiles`, `profile_category` enum (incl. 3 provider types), `profile_verification_status` |
| 056 | `provider_profile_extensions` |
| 057 | `laundry_provider_services` |
| 058 | `saved_locations`, `location_source`, `location_type` enums |
| 059 | `provider_service_areas` |
| 071 | `garbage_providers`, `garbage_provider_assignments`, `garbage_assignment_type`, `garbage_provider_status`, `collection_frequency` |
| 072 | `garbage_collection_requests`, `collection_request_status`, `collection_request_type`, `unit_occupancy_history` |
| 100 | `moving_requests`, `moving_status_history`, `moving_request_status` (8), `moving_service_type` (8) |
| 101 | `laundry_requests`, `laundry_status_history`, `laundry_request_status` (8), `laundry_service_category` (6), `laundry_collection_preference` (3) |
| 103 | Multi-provider payment support, `unmatched_payments`, `payment_reversals`, `payment_callback_audit` |

**There is no unified `service_requests` table.** Three domain-specific request tables exist, each with its own status enum and a status-history table/trigger.

### 2.6 Payments, outbox, workers

- **Payments** (`payment.service.ts`, `payment.provider.ts`): adapter pattern (`mpesa_daraja`, `mpesa_paybill`, `mpesa_till`, `pesapal`). Tables: `invoices`, `payment_transactions`, `rent_ledger_entries`, `receipts`. **No provider payout/commission** anywhere (single seed `financial.approve_payouts` in migration 037; `service-requests.schema.ts:321-352` defines a `providerEarningsResponseSchema` that is not wired to any route).
- **Transactional outbox** (`transactional-outbox.service.ts:70-109`): critical-event set does **not** include `moving_request.created`, `garbage_request.created`, `laundry_request.created` — they are emitted but classified `best_effort` (reliability risk).
- **Workers**: `jobs/boss.ts` and `jobs/register-workers.ts` are **empty (0 lines)** — no pg-boss. Existing workers (`notification.worker.ts`, `search-alert.worker.ts`, `site-visit-reminder.worker.ts`, `mpesa-reconciliation.worker.ts`) use `setInterval`.

### 2.7 Flutter (`Mobile/lib/`)

- Service features `movers`, `garbage`, `laundries` are **full implementations** (datasource, repository, model, Riverpod `Notifier` state, list + form pages) — not stubs.
- Datasources call tenant endpoints via `apiClient.dio` (see §10 defect, now fixed).
- Routing (`app_router.dart:924-948`): `/tenant/garbage`, `/tenant/movers`, `/tenant/laundries` guarded by `isAuthenticated` only (no role/active-account guard).
- Auth (`auth_state.dart`, `auth_models.dart`): `AuthUser.roles: List<String>`; registration offers provider account types (`register_page.dart:28-34`). No active-account/role enforcement on tenant routes.
- Organizations feature: full CRUD-ish (datasource uses relative `/organisations`); member role/status update present.
- **No provider-facing screens** (dashboard, inbox, job management, quotation builder, earnings) exist.
- Localization: `l10n.yaml` + `app_en.arb`/`app_sw.arb` present and generated.
- Known minor defects: `moving_page.dart:63` identical-branch ternary; `moving_request_form_page.dart:41` hardcoded empty `pickupUnitId`.

---

## 3. Existing Components to Reuse (do not duplicate)

| Component | Reuse for |
|-----------|-----------|
| `specialized_profiles` + `provider_profile_extensions` + `laundry_provider_services` | Provider identity for all 3 domains |
| `provider_service_areas` | Coverage for all 3 |
| `saved_locations` (`provider_operating`, `business_office`, `service_area`) | Business/operating locations |
| `profile_verification_*` + admin verification queue | Provider onboarding/approval |
| `organisations` + `organisation_members` | Provider companies + staff |
| `authorization.service.ts` (`canAccessTenancy`, `canAccessProperty`, `canAccessUnit`, `authorize`) | Request/property authorization |
| `transactional-outbox` + `notification.worker` | Lifecycle notifications |
| `payments` adapter pattern + `invoices`/`payment_transactions`/`payment_allocations` | Service invoicing/collections |
| `messaging` module (contextual conversations) | Request-scoped customer↔provider chat |
| `location/provider-discovery.repository.ts` | Distance-based discovery (needs HTTP exposure) |
| Riverpod `Notifier` + `apiClient.dio` + GoRouter + design system + l10n | Flutter provider app |

## 4. What Must NOT Be Duplicated

| Anti-pattern | Correct approach |
|--------------|------------------|
| A second auth system for providers | Single user identity + `specialized_profiles` + org membership |
| A second `garbage_providers` model | Converge on `specialized_profiles` (`garbage_collection_provider`); keep `garbage_provider_assignments` referencing a profile id |
| Three unrelated request/notification/scheduling stacks | One shared request foundation + domain extensions |
| Provider-specific Paybill/Till | Central collections only |
| Duplicate payment/ledger tables | Extend `invoices`/`payments`/`payment_allocations` |
| Background/continuous location tracking | None; opt-in, time-boxed job tracking only if ever added |

---

## 5. Blueprint Alignment and Discrepancies

The blueprint (`System_Design_Blueprint_Plain_Black.pdf`) is intentionally high-level and defers detailed status workflows to "detailed requirements analysis."

| # | Blueprint says | Repository reality | Discrepancy |
|---|----------------|--------------------|-------------|
| D1 | Platform = house search + RMS + **movers** + **garbage** | Laundry fully present in code/DB | **Laundry is an extension beyond the blueprint** — not a blueprint requirement |
| D2 | Single account, multiple roles; mover "manages their own service profile and requests" (§6.6.3) | No provider-facing request management exists | Provider request handling missing |
| D3 | Garbage: property↔provider association, provider change workflow, tenant limited to "report missed / request" (§6.5.5–6.5.6) | Assignments + landlord CRUD exist; **no provider-change workflow, no missed-collection flow** | Partial |
| D4 | Moving request statuses "submitted, under review, accepted, declined, completed" (§6.4.4) | Enum has 8 states incl. `pending_confirmation`, `scheduled`, `in_progress`; no transition enforcement | Enum richer than blueprint; no service-layer transition validation |
| D5 | Provider discovery by location/service type (§6.4.2) | Distance query exists but **not exposed via API** | Discovery not reachable by clients |
| D6 | Out of scope: **fleet mgmt, route optimization, driver mgmt, automated collection logistics, quality/price guarantees** | — | Roadmap must **exclude** these (prior roadmap over-reached) |
| D7 | Two provider models implied (individual movers + companies) | `specialized_profiles` (individual) + `organisations` (company) both exist; garbage also has separate `garbage_providers` | Dual garbage model is a discrepancy to converge |
| D8 | Admin oversight of providers (§6.8.2) | Verification queue exists; no provider suspension/quality admin | Partial |

---

## 6. Provider Role & Permission Matrix (target)

Single identity; provider capability is additive and scoped. **Property managers, landlords, and caretakers never gain provider privileges automatically; a provider profile never grants access to a customer's property or tenancy.**

### 6.1 Organization roles (current vs. target)

Current `organisationRoleSchema` = `owner | admin | member | staff` (`auth.schema.ts:296`). Target extension (additive, backward compatible):

| Role | Scope | Key permissions |
|------|-------|-----------------|
| Owner | Org-global | All; staff mgmt; finance; verification |
| Admin | Org-global | Staff mgmt, service config, oversight (no owner-only actions) |
| Supervisor / Ops Manager | Service-domain | Assignment, scheduling, QC for a domain |
| Dispatcher / Coordinator | Service-domain | Routing, customer comms, schedule mgmt |
| Operational Staff | Assignment | View/update **assigned** jobs only |
| Finance Staff | Org read / domain write | Invoicing, reconciliation, payout requests |

### 6.2 Permission matrix (target; `provider.*` already partially seeded)

| Permission | Org-global | Domain | Assignment |
|------------|-----------|--------|-----------|
| `provider.view` | ✓ | ✓ | ✓ |
| `provider.manage_profile` | owner/admin | owner/admin | — |
| `provider.manage_services` | owner/admin | +supervisor | — |
| `provider.manage_assignments` | owner/admin | supervisor/dispatcher | dispatcher |
| `provider.manage_staff` | owner/admin | — | — |
| `provider.view_financials` | owner/admin/finance | finance | — |
| `provider.manage_payouts` | owner/finance | — | — |
| `job.view_assigned` / `job.update_status` / `job.communicate_customer` | — | — | assigned staff |

**Rule:** org membership alone never grants access to a customer request; access requires service-area match (discovery) **and** explicit assignment/consent.

---

## 7. Missing or Incomplete Features

| Component | Status | Gap |
|-----------|--------|-----|
| Moving/laundry request **list** (GET) | Missing | Only POST/DELETE exist; Flutter list screens 404 |
| Provider-facing API (`/api/v1/provider`) | Missing | No namespace at all |
| Request discovery for providers | Missing | Discovery repo not exposed; no "inbox" |
| Quotation / negotiation (moving) | Missing | No tables/service |
| Job assignment, scheduling, status, completion | Missing | No endpoints; status enums unused beyond create/cancel |
| Recurring garbage collection | Missing | No templates/scheduler |
| Provider change workflow (garbage) | Missing | Blueprint §6.5.5 |
| Missed-collection reporting | Missing | Blueprint §6.5.6 |
| Outbox classification for request events | Incomplete | Created events not in critical set |
| Provider verification admin review beyond queue | Partial | No suspension/quality flags |
| Provider payouts/commission | Missing | Schema-only, not wired |
| Provider Flutter app | Missing | No provider screens |
| Distance discovery HTTP + map service-area UI | Missing | Repo only; text fallback needed |
| pg-boss job queue | Missing | Empty files; `setInterval` only |

---

## 8. Recommended Domain Architecture

**Shared request foundation + domain extensions**, mirroring the payments adapter pattern. Reuse the three existing request tables rather than discarding them; introduce a thin shared layer (status-transition service, assignment, notifications) and per-domain extension tables only where the workflow genuinely diverges.

```
modules/service-requests/
├── service-requests.routes.ts        # /api/v1/tenant + /api/v1/provider
├── service-requests.service.ts       # shared lifecycle + domain dispatch
├── service-requests.repository.ts    # shared queries across 3 tables
├── service-requests.schema.ts        # (exists) base + domain schemas
├── status-transitions.ts             # allowed-transition matrix per domain
├── moving/        (quotation, inventory, scheduling)
├── garbage/       (recurring templates, missed-collection, provider-change)
└── laundry/       (pickup/delivery, facility tracking, pricing)
```

### 8.1 Boundaries — share vs. keep separate

| Share | Keep domain-specific |
|-------|----------------------|
| Request identity, customer/property/unit linkage, status history, assignment, notifications, messaging, attachments, ratings, disputes, invoicing | Moving quotation/negotiation & inventory; Garbage recurring templates & provider-change; Laundry pickup/delivery & per-item facility tracking |

Do **not** force moving negotiation, garbage recurring schedules, or laundry logistics into one oversized generic schema; do **not** build three unrelated notification/assignment stacks.

---

## 9. Request-to-Completion Lifecycles (target)

### 9.1 Moving
`submitted → pending_confirmation → accepted → scheduled → in_progress → completed` (branches: `declined`, `cancelled`, `disputed`).
Create: tenant/house-seeker (`canAccessTenancy` or saved location). Discover: providers in service area. Quote→negotiate (≤3 rounds)→accept. Schedule→assign crew→status updates→deliver→customer confirm→invoice→(future) payout.

### 9.2 Garbage
`submitted → acknowledged → scheduled → in_progress → completed` (branches: `unable_to_fulfil`→`rescheduled`, `missed_reported`, `cancelled`, `disputed`).
Create: tenant/caretaker/PM/landlord (property-scoped). Auto-route via `garbage_provider_assignments`. Recurring via template (no auto-duplicate). Provider change: landlord-initiated → approval → effective-date transition.

### 9.3 Laundry (extension, not in blueprint)
`submitted → pending_confirmation → accepted → scheduled → picked_up → in_progress → ready_for_delivery → delivered → completed` (branches: `declined`, `cancelled`, `quality_dispute`).
Create: tenant (`canAccessTenancy`), provider required. Optional weight-based quote. Pickup→process→ready→deliver→confirm→rate.

**Authorization for all:** no access by request id alone — require customer ownership, service-area match, or explicit assignment. Landlord/caretaker scoped to their properties; providers never see unrelated customers' private coordinates.

---

## 10. Defects Fixed During This Audit

**Foundational fix (applied):** five Flutter tenant datasources built absolute URLs missing the `/api/v1` prefix while the backend mounts tenant routes only at `/api/v1/tenant` (`app.ts:81`). This made **all** tenant list/create calls 404 (moving, garbage, laundry, tenancies, maintenance). Corrected `_basePath` in each:

- `Mobile/lib/features/movers/data/datasources/moving_remote_datasource.dart:12`
- `Mobile/lib/features/garbage/data/datasources/garbage_remote_datasource.dart:12`
- `Mobile/lib/features/laundries/data/datasources/laundry_remote_datasource.dart:12`
- `Mobile/lib/features/tenancies/data/datasources/tenancy_remote_datasource.dart:14`
- `Mobile/lib/features/maintenance/data/datasources/maintenance_remote_datasource.dart:12`

Each now targets `${ApiConfig.baseUrl}/api/v1/tenant/...`. `flutter analyze` on the touched features reports only pre-existing infos/warnings (no new errors). No tests referenced the old paths.

**Documented, not fixed (out of 13.1 scope):** missing `GET /moving-requests` and `GET /laundry-requests` (list) endpoints; `moving_page.dart:63` identical-branch ternary; hardcoded empty `pickupUnitId` in the moving form; outbox critical-event classification; empty pg-boss files.

---

## 11. Exact Files and Modules Inspected

**Backend:** `server/src/app.ts`; `modules/tenant/{tenant.routes.ts,tenant.controller.ts,tenant.repository.ts,tenant.schema.ts}`; `modules/profile/{profile.routes.ts,profile.repository.ts,profile.schema.ts,profile.types.ts}`; `modules/location/{provider-discovery.repository.ts,provider-discovery.schema.ts,location-sharing.routes.ts}`; `modules/landlord/{landlord.routes.ts,landlord.controller.ts}`; `modules/auth/{authorization.service.ts,authorization.middleware.ts,auth.schema.ts,organization.service.ts}`; `modules/payments/{payment.service.ts,payment.provider.ts}`; `modules/service-requests/service-requests.schema.ts`; `modules/messaging/*`; `db/migrations/{055,056,057,058,059,071,072,100,101,103}`; `jobs/{boss.ts,register-workers.ts}` (empty); `openapi.yaml`; `System_Design_Blueprint_Plain_Black.pdf`.

**Flutter:** `core/config/api_config.dart`; `core/api/api_client.dart`; `features/{movers,garbage,laundries}/**`; `features/tenancies/data/datasources/tenancy_remote_datasource.dart`; `features/maintenance/data/datasources/maintenance_remote_datasource.dart`; `features/organizations/data/datasources/organisation_remote_datasource.dart`; `features/authentication/**`; `app/router/app_router.dart`; `l10n.yaml`, `lib/l10n/app_{en,sw}.arb`.

**Docs:** `docs/architecture/service-provider-platform-audit.md` (this file), `service-provider-platform-implementation-roadmap.md`, `backend-architecture.md`, `flutter-architecture.md`, `maintenance-garbage-and-financial-reporting.md` (outdated re: Flutter stubs).

---

## 12. Documentation Created/Updated

- `docs/architecture/service-provider-platform-audit.md` (rewritten, this file)
- `docs/architecture/service-provider-platform-implementation-roadmap.md` (rewritten)

---

## 13. Remaining Architectural Uncertainties

| Uncertainty | Impact | Resolution |
|-------------|--------|-----------|
| Laundry not in blueprint | Scope legitimacy | Confirm laundry is an approved extension |
| Converging `garbage_providers` → `specialized_profiles` | Data migration risk | Plan idempotent backfill in 13.3 |
| Google Maps availability | Map service areas / distance | Text + radius fallback now; maps later |
| Payout rails (M-Pesa B2C limits) | Provider payouts | Batch payouts; manual approval; future task |
| Multi-service orgs | Permission scoping | Single-domain first, multi-domain in 13.4 |
| Recurring garbage generation | Duplicates | Template-based, idempotent, per-cycle confirmation |
| Live job tracking privacy | Critical | Opt-in, time-boxed; likely defer beyond blueprint scope |
| Quotation vs fixed pricing per domain | Pricing models | Moving negotiate; garbage plans; laundry per-kg/item |

---

## 14. Recommended Next Task

**Task 13.2 — Shared Provider Domain Foundation and Authorization.** Add the missing `GET /moving-requests` and `GET /laundry-requests` list endpoints; introduce the shared `service-requests` service/repository/status-transition layer over the existing three tables; expose provider discovery over HTTP; extend authorization with provider/assignment scope; classify request events as critical in the outbox. This unblocks all provider-facing work (13.3–13.12). Do not begin 13.2 until this audit and the roadmap are approved.