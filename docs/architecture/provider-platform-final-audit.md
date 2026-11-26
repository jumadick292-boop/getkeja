# Provider Platform — Final Audit (Task 13.17)

Final security, integration, UX and release audit of the GetKeja provider
platform following Tasks 13.1–13.16. This document records findings and
remediation; the verdict lives in
`docs/reports/TASK_13_17_PROVIDER_PLATFORM_FINAL_AUDIT_REPORT.md`.

## 1. Repository baseline
- Branch `main`, HEAD `b550497` ("installation-operations … wifi/internet/solar"),
  which contains Tasks 13.1–13.14 + unified scheduling + readiness docs.
- Working tree: **82 modified, 271 untracked**. Tasks 13.15 (finishing) and
  13.16 (dashboard/reports/reviews/complaints) are uncommitted, alongside many
  12.x/13.x files.
- Debug/temp artifacts present (untracked, **not deleted**): `server/diag.ts`,
  `server/apply_097.mjs`, `server/test_column.mjs`,
  `server/test_proposal_debug.mjs`. Recommend removal before release.
- No `git reset`/`clean`/revert performed; no commits made.

## 2. Catalogue (corrected)
- **18 service domains, 55 active categories** (the Task 13.11 readiness doc's
  "53" is stale — migrations 116/118 added `garbage_household/bulky/organic`
  and `laundry_wash_fold/dry_clean/iron_only/textile`).
- All 55 categories are fully operational (schema → offering → request →
  discovery/eligibility → quotation → exactly-once job creation → lifecycle →
  scheduling). No partial categories.
- Separation-critical categories remain distinct: `wifi_installation`,
  `internet_installation`, `solar_installation`, `painting`,
  `painting_decoration` (the task's "painting_and_decoration" slug is actually
  `painting_decoration`).
- Structural note: category→module routing is by `service_domain` convention,
  not a hard per-category code map; exactly-once creation is enforced by a
  unique index on `service_request_id` in each job table.

## 3. Scheduling
- 8 `SchedulingDomain` values; `loadResource` resolves all 7 job tables +
  `garbage_recurring_occurrences`. DB CHECK (exactly-one resource),
  per-resource partial unique indexes, `end_at > start_at`, and a GiST
  `EXCLUDE` preventing double-booking.
- Single writer (`scheduling.service`); no operational module writes the table
  directly. Operational lifecycles do **not** auto-create schedules (opt-in via
  `POST /scheduling/activities`); `site-visits` runs its own reminder subsystem
  outside the unified scheduler (by design).

## 4. Identity / authorization
- `resolveProviderContext` derives access from data (memberships, active org,
  approved profiles), never role names; cross-org escalation via
  `x-organization-id` is blocked (validated against memberships).
- Provider operational/scheduling routers use `requireAuth` only; authorization
  is enforced **in services** (`assertProviderAccess`, `effectiveProfileIds`,
  `canAccessProviderRequest`). Sound but no defense-in-depth middleware (B-1).
- Auth/tenancy/IDOR suites pass (133 tests), including cross-user access denial.

## 5. Attachments & privacy
- Messaging/rental/verification uploads validate size + MIME (magic bytes) and
  serve via short-lived presigned URLs after participant authz.
- Property-document signed-URL endpoint is behind `requireAuth` (not public).
- Gaps: **C-1** `canAccessPropertyDocument` ignores the document's own
  `visibility`/`allowed_roles`/`allowed_user_ids`/`allowed_organisation_ids`
  (IDOR-adjacent, HIGH); **C-2** signed-URL trusts token for up to 1h without
  re-authz (MEDIUM); **C-4** cleaning/installation/finishing attachments store a
  free-form `document_id` (no FK/ownership binding, no MIME/size check) and
  return the id to customers (MEDIUM).
- Location: continuous GPS is opt-in, site-visit scoped, throttled, and purged;
  provider discovery returns only `distanceKm` + public fields; request detail
  masks contact/coords for unassigned requests. **PASS.**
- Logging: Pino has no `redact` paths and the error handler logs raw `err`
  (**C-3**, LOW/latent); request bodies/headers are not auto-logged.

## 6. Dashboard / reporting / reviews / complaints
- Unified dashboard returns `{ scope, metrics, byDomain, filters }`; Flutter
  reads `metrics` (contract matches). Org filtering via active org; no
  cross-org leakage (profile-scoped queries).
- Reviews: eligible = completed + customer-confirmed, one per job (unique),
  ratings from published only. Complaints: only `closed` terminal, internal
  notes admin-only, no job-status/payment mutation. **PASS.**

## 7. Flutter navigation / UX / l10n
- Fixed: broken `pushNamed('profile-locations')` → `profile-location`; dashboard
  Laundries/Movers/Garbage tiles now navigate to real routes; added a
  "For providers" entry to `/provider/dashboard`.
- Remaining: provider setup pages (services, locations, service-areas,
  availability, onboarding, organizations, provider marketplace inbox) and most
  operations **list** pages remain reachable only via deep links/notifications;
  Explore/Visits dashboard tabs are "coming soon" placeholders; `app_sw.arb`
  has many untranslated English values and a few wrong translations; several
  `provider` feature pages and the dashboard/profile use hard-coded English.
- Localization key sets en/sw are identical (612 each); fixed house-seeker
  placeholders and `noHomesMatch` Swahili.

## 8. House-seeker test failures (resolved)
The six `Bad state: No element` failures (compare clear, saved-search
delete/run/toggle/error) plus a Swahili empty-state failure were caused by
placeholder English/Swahili l10n values and one untranslated key. Fixed the l10n
(en+sw), regenerated, and added `house_seeker_l10n_regression_test.dart`.
Full Flutter suite: **238 passed, 0 failed**.

## 9. Backend verification (batched)
50 DB-backed test files, `fileParallelism:false`. Full sequential run exceeds
10 min wall-time (not a failure); run in 7 domain batches — **660 tests, all
passing**. Legacy provider dashboard tests updated to the unified contract
(the endpoint is legitimately served by the Task 13.16 router). See report for
the matrix.

## 10. API / OpenAPI / migrations
- 319 paths, **0 dangling schema refs** (added the 8 missing payment/landlord
  schemas). Routers mounted once; dashboard/reports before legacy provider.
- Migrations applied through `provider_complaints`; no pending; idempotent.
- Note: legacy `provider.routes` `/dashboard` handler is shadowed/dead (LOW,
  informational) — no live Flutter consumer.

## 11. Payments / performance / deployment
- Payments: 55/55 tests pass (central Paybill/Till + Pesapal/Daraja, callback
  auth + idempotency); no provider-specific tills introduced.
- Performance: indexes + pagination present; no production benchmarks run on dev
  DB (NOT VERIFIED for load).
- Deployment: `.env.example` comprehensive; `/health` + `/ready`; SIGTERM
  graceful shutdown; migration procedure documented. External creds
  (Pesapal/Daraja/Cloudinary/Maps/SMS/email) required for production.

## 12. Remediation status
Fixed in 13.17: house-seeker l10n + regression test, broken route name,
dashboard dead tiles + provider entry, OpenAPI dangling refs, legacy dashboard
test alignment.

Fixed in 13.18 (see `TASK_13_18_RELEASE_GATE_REMEDIATION_REPORT.md`):
- **C-1 (High)** — `canAccessPropertyDocument` enforces the document's own
  `visibility` + allow-list columns and real property relationships
  (ownership/manager/caretaker/tenant/org), fails closed, applied to
  read/preview/download/signed-URL paths. 21 regression tests pass.
- **C-2 (Medium)** — signed-URL redemption re-authorizes; revocation effective
  at redemption (proven by test).
- **C-3 (Low)** — Pino `redact` paths added.
- **Navigation** — provider dashboard links setup/onboarding/organizations/
  services/locations/service-areas/availability/marketplace/operations; home
  dashboard has onboarding + dashboard entries; Explore/Visits open real
  screens. Flutter nav tests pass.

Remaining: **C-4 (Medium)** operational attachment integrity (no FK/ownership/
MIME; internal `documentId` returned to customers) — not a direct file leak;
broader Swahili/hard-coded l10n; load perf not benchmarked; debug artifacts to
remove.
## 13. Final reassessment (Task 13.19)
Re-verified on the live repo (HEAD b550497, 83 modified / 277 untracked):
C-1/C-2/C-3 fixes present in code and proven (document-authorization 21/21).
Backend re-run green across all 50+1 suites (provider/marketplace/scheduling/
7 operations 127; payments/auth/messaging/notifications 219; remaining 25
files green). Flutter analyze 0 errors, full suite 244/244. OpenAPI 319 paths /
0 dangling; migrations pending 0; tsc clean. C-4 re-assessed as non-blocking
(no direct file endpoint; download authz-gated; only generic metadata exposed).
Load performance NOT VERIFIED (empty dev DB; seq scans not representative).
Verdict: READY FOR CONTROLLED BETA with documented limitations.
