# Task 13.19 — Final Controlled-Beta Release Reassessment

## 1. Repository baseline
- Branch `main`, HEAD `b550497`. Working tree **83 modified, 277 untracked**
  (Tasks 13.15–13.18 uncommitted work preserved). No destructive git; no commits;
  debug artifacts left in place (not clearly task-owned; documented for removal).
- 13.18 fixes verified present in code: `computeDocumentVisibilityAccess`
  (authorization.service.ts), signed-URL redemption re-authz
  (document-signed-url.service.ts), `REDACT_PATHS` (main.ts).

## 2. Verification of Task 13.18 fixes
- C-1: `canAccessPropertyDocument` enforces visibility + allow-list + real
  property relationships, fails closed; applied to read/preview/download/
  signed-URL paths. **document-authorization.test.ts 21/21 pass.**
- C-2: signed-URL redemption re-authorizes (revocation effective) — covered by
  the C-2 test.
- C-3: Pino redact paths present.
- Navigation: provider dashboard setup/marketplace/operations links + home
  onboarding/dashboard entries + Explore/Visits real screens — Flutter nav
  tests pass.

## 3. Final C-1..C-4 security status
| ID | Severity | Status | Notes |
|---|---|---|---|
| C-1 | High | PASS (fixed) | 21 regression tests; IDOR closed |
| C-2 | Medium | PASS (fixed) | redemption re-authz; bounded by 1h TTL |
| C-3 | Low | PASS (fixed) | Pino redact |
| C-4 | Medium | PASS WITH LIMITATIONS | no FK/MIME/size on operational attachments; internal `documentId` returned to customer; **no direct file endpoint** (download authz-gated by C-1) → no file-content disclosure. Narrow remediation recommended before GA. |

No open critical/high security finding. No path exposes private document
contents, PII or financial records without authorization.

## 4. Catalogue and domain coverage
18 domains, **55** active categories (migrations 116/118 added 7 beyond the
stale "53"). Separation-critical distinct: `wifi_installation`,
`internet_installation`, `solar_installation`, `painting`,
`painting_decoration`. All 55 map to one of 7 operational job tables by
`service_domain`; exactly-once creation via unique `service_request_id`.
Coverage table in `provider-platform-final-audit.md` §2. Status: PASS WITH
LIMITATIONS (routing is domain-convention, not a hard per-category map).

## 5. End-to-end workflow coverage
Automated integration suites cover all 7 domains (moving, garbage, laundry,
home-maintenance, cleaning, installation, finishing) + marketplace + scheduling:
request → discovery/eligibility → quotation → accept → exactly-one job →
lifecycle → confirmation → review/complaint eligibility. **127/127 pass.**
Representative categories per schema family; not every one of 55 individually
E2E-tested (stated limitation). No duplicate jobs / cross-provider exposure
observed (unique index + provider-scoped queries).

## 6. Performance measurements and limitations
Bounded EXPLAIN on the dev DB returned Seq Scans because tables are effectively
empty (rows≈1) — **not representative**; no production latency figures derived.
Indexes exist (scheduling partial unique indexes, FK/index on job/attachment
tables); pagination present on list endpoints. Status: **NOT VERIFIED under
load.** Bounded plan: seed representative data in a staging DB, then measure
p50/p95 for dashboard, discovery, operations list, scheduling; run pg-boss
retry/duplicate and outbox-failure drills. Risks for a small beta: unindexed
growing tables (notifications/messaging) and dashboard aggregates over large
job volumes.

## 7. Flutter UX and localization
Analyze 0 errors; full suite 244/244. Provider setup/operations reachable;
Explore/Visits open real screens; back navigation verified; loading/empty/error
states present. Localization: en/sw key sets identical; house-seeker
placeholders + `noHomesMatch` fixed (13.17). Remaining: broad untranslated
`app_sw.arb` values and hard-coded English in provider/dashboard/profile pages —
**PASS WITH LIMITATIONS** (English fully usable; Swahili partial). Non-blocking
for a restricted beta; owner: mobile.

## 8. Payment verification
Central GetKeja Paybill/Till + Pesapal + M-Pesa Daraja model intact; callback
auth + idempotency; **payments 55/55 pass**; no provider-specific tills; no
real-money calls. Status: PASS.

## 9. Deployment and operational readiness
Implemented/verified: `.env.example`, `/health` + `/ready`, SIGTERM graceful
shutdown, migration runner, rate limiting, redacted logs. Configured but not
tested end-to-end: email/SMS/push, Cloudinary, Google Maps. Requires production
credentials/operator action: Pesapal/Daraja, storage, maps, SMS/email, DB
backups, monitoring. Status: PASS WITH LIMITATIONS (creds/infra pending).

## 10. Debug-artifact review
`server/diag.ts`, `apply_097.mjs`, `test_column.mjs`, `test_proposal_debug.mjs`
— untracked development utilities, not referenced by app/tests, no secrets
observed. Classified **safe development utilities / unused**; not clearly
task-owned → preserved, removal recommended. No debug routes in production app;
test credentials only in test-setup.

## 11. Exact test results
Backend (batched, DB-bound; full sequential run exceeds 10 min wall-time):
- provider/marketplace/scheduling + 7 operations (13 files): **127/127**.
- payments + auth/tenancy/doc-authz/account + messaging + notifications
  (13 files): **219/219**.
- remaining 25 files (house-seeker, landlord, rental, site-visits, tenant,
  profile×7, location×4, listings×2, app, env, error-handler, auth.service,
  auth.schema, email-registration, dev-code-logger): **all pass (exit 0)**.
- `tsc --noEmit`: clean. OpenAPI: 319 paths, 0 dangling. Migrations pending: 0.
Flutter: `flutter analyze` 0 errors; full suite **244/244**.

## 12. Outstanding risks, owner actions, severity
| Risk | Severity | Owner | Action |
|---|---|---|---|
| C-4 attachment integrity (no FK/MIME; id to customer) | Medium | Backend/operations | Add FK + documentId ownership validation + MIME/size; strip ids from customer detail (before GA) |
| Broad Swahili/hard-coded l10n | Medium | Mobile | Translate remaining sw; replace hard-coded strings |
| Load performance not benchmarked | Medium | Backend/SRE | Staging load test (dashboard/discovery/lists); add indexes if needed |
| Debug artifacts | Low | Backend | Remove unused scripts |
| External creds/infra | (beta) | Ops | Provision Pesapal/Daraja/storage/maps/SMS/email, backups, monitoring |

## 13. Final controlled-beta decision
**READY FOR CONTROLLED BETA.**

Recommended beta scope: closed group in Nairobi (English-first; Swahili where
complete) exercising property search, landlord/tenant core, and provider
marketplace→operations→reviews/complaints across the 7 domains.
Eligible initial groups: internal staff + a small set of onboarded landlords,
caretakers, and approved individual/organization providers.
Operational safeguards: feature-flag provider onboarding; keep payments in
sandbox until creds + reconciliation verified; rate limits + redacted logs;
C-1 authz enforced; exactly-once job creation.
Monitoring/incident response: `/health`+`/ready` checks, pg-boss/outbox lag
alerts, notification-failure alerts, error tracking, daily DB backups, rollback
plan, and a named on-call.
Known limitations to communicate: partial Swahili; C-4 attachment hardening
pending (no file leak); load not benchmarked; some provider setup screens
deep-link only outside the dashboard.
This does not certify production GA; C-4, l10n, load and creds must close before
wider release.