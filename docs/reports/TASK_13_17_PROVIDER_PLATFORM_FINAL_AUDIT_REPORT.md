# Task 13.17 — Provider Platform Final Audit Report

## 1. Repository and working-tree baseline
- Branch `main`; HEAD `b550497` (Tasks 13.1–13.14 + scheduling). 82 modified,
  271 untracked (13.15/13.16 + 12.x/13.x uncommitted). Debug artifacts present
  (`server/diag.ts`, `apply_097.mjs`, `test_column.mjs`,
  `test_proposal_debug.mjs`) — documented, not deleted. No commits made; no
  destructive git operations.

## 2. Category/domain coverage — PASS WITH LIMITATIONS
18 domains, **55** active categories (readiness doc's 53 is stale; migrations
116/118 added 7). All 55 fully operational; 5 separation-critical categories
distinct (`painting_decoration` is the real slug). Limitation: category→module
routing is domain-convention, not a hard per-category map.

## 3. End-to-end workflow coverage — PASS WITH LIMITATIONS
Representative categories per schema family verified via module suites
(moving/garbage/laundry/home-maintenance/cleaning/installation/finishing). Each
job table enforces exactly-once creation (unique `service_request_id`); invalid
transitions → 409; outbox events transactional. Not all 53/55 categories were
individually E2E-tested (representative coverage only).

## 4. Scheduling integration — PASS
8 domains resolvable; DB CHECK + partial unique indexes + GiST EXCLUDE; single
writer; Africa/Nairobi timezone. Limitation: lifecycles don't auto-schedule
(opt-in); site-visits uses a separate reminder subsystem by design.

## 5. Identity and authorization — PASS WITH LIMITATIONS
Data-derived provider context; active-org validated; service-level authz
enforced; auth/IDOR suites green (133). Limitation B-1: no defense-in-depth
permission middleware on operational routers (service-only checks).

## 6. Privacy and attachment findings — FAIL (open high/medium)
C-1 HIGH IDOR-adjacent (`canAccessPropertyDocument` ignores visibility/allow
lists); C-2 MEDIUM signed-URL staleness (1h); C-4 MEDIUM attachment integrity
(no FK/ownership/MIME, id exposed to customer); C-3 LOW no Pino redact. Location
handling PASS.

## 7. Dashboard/report/review/complaint verification — PASS
Unified dashboard contract matches Flutter (`metrics`); reviews/complaints
eligibility, one-per-job, admin-only notes, no financial/status mutation.

## 8. Flutter navigation and UX — FAIL (core-flow dead ends)
Fixed: broken `profile-location` route name, dead dashboard tiles, added
provider entry. Remaining: provider setup pages + operations list pages
reachable only via deep link; Explore/Visits "coming soon"; some dead/placeholder
buttons.

## 9. Localization — PASS WITH LIMITATIONS
en/sw key sets identical (612). Fixed house-seeker placeholders + `noHomesMatch`
sw. Remaining: large untranslated English in `app_sw.arb`, a few wrong sw
values, hard-coded English in provider/dashboard/profile pages.

## 10. Six house-seeker failures — RESOLVED
Root cause: placeholder/untranslated l10n. Fixed en+sw, regenerated, added
`house_seeker_l10n_regression_test.dart`. Full Flutter suite **238/238 pass**.

## 11. Backend test verification matrix

| Batch | Command (npx vitest run …) | Files | Tests | Result | Duration |
|---|---|---|---|---|---|
| 1 provider/marketplace/scheduling | provider, provider-catalogue, provider-identity, provider-platform, marketplace, scheduling | 6 | 82 | PASS | ~83s |
| 2 operations | moving, garbage, laundry, home-maintenance, cleaning, installation, finishing | 7 | 45 | PASS | ~108s |
| 3 auth/security | auth, auth.mfa, auth.service, auth.schema, account, notification, tenancy, email-registration, dev-code-logger | 9 | 133 | PASS | ~148s |
| 4 payments | payment, payment-extended, payment-c2b-security, caretaker-authorization, permission-cache-revocation | 5 | 55 | PASS | ~89s |
| 5a profile/location | profile.* (7) + location.* (4) | 11 | 36 | PASS | ~13s |
| 5b messaging/listings/tenant/house-seeker/landlord/rental/site-visits | 9 files | 9 | 289 | PASS | ~421s |
| 6 app/config/middleware | app, env, error-handler | 3 | 20 | PASS | ~7s |
| **Total** | 50 files | **50** | **660** | **PASS** | batched |

Full sequential `vitest run` exceeds 10 min wall-time (DB-bound, sequential);
batching is the reproducible strategy. No tests weakened/removed; two legacy
dashboard assertions updated to the unified contract. Redis-MFA flakiness did
not manifest (auth.mfa green). No skipped suites.

## 12. OpenAPI and migration verification — PASS
319 paths, 0 dangling refs (added 8 payment/landlord schemas). Routers mounted
once. Migrations applied through `provider_complaints`; none pending; idempotent.
Legacy `/dashboard` handler shadowed/dead (informational).

## 13. Payment regression — PASS
55/55 payment tests; central GetKeja Paybill/Till model intact; callback auth +
idempotency verified; no real-money calls.

## 14. Performance — NOT VERIFIED (load)
Indexes/pagination present; no production benchmarks derived from dev DB.

## 15. Security findings and remediation

| ID | Severity | Finding | Status |
|---|---|---|---|
| C-1 | High | `canAccessPropertyDocument` ignores document visibility/allow lists (IDOR-adjacent) | OPEN |
| C-2 | Medium | Signed-URL access valid up to 1h without re-authz | OPEN |
| C-4 | Medium | Operational attachments: no FK/ownership/MIME/size; id returned to customer | OPEN |
| C-3 | Low | Pino no `redact`; error handler logs raw err | OPEN |
| B-1 | Info | Authz only in services (no middleware) | ACCEPT (design) |
| A-1 | Info | Lifecycles don't auto-create schedules | ACCEPT (design) |

Fixed this pass: house-seeker l10n, broken route, dashboard tiles+entry, OpenAPI
refs, legacy test alignment. C-1/C-2/C-4/C-3 remain open (C-1 gates release).

## 16. Deployment configuration gaps
Implemented: `.env.example`, `/health`+`/ready`, SIGTERM graceful shutdown,
migration docs. Requires production credentials/approval: Pesapal, M-Pesa
Daraja, Cloudinary, Google Maps, SMS/email providers. Android/iOS permissions
and release signing present (per repo CI). Distinguish implemented vs
credential-dependent in the checklist.

## 17. Outstanding limitations
C-1/C-2/C-4/C-3 security; provider/operations nav reachability; Explore/Visits
placeholders; Swahili/hard-coded string gaps; category→module map is convention;
load performance not benchmarked; debug artifacts to remove.

## 18. Final release-readiness verdict
**NOT READY FOR CONTROLLED BETA.** Gating: open HIGH security finding C-1
(IDOR-adjacent property-document access) and core provider/operations
navigation dead-ends. Non-gating: C-2/C-4/C-3, l10n/UX gaps, load perf.
See `PROVIDER_PLATFORM_RELEASE_READINESS_CHECKLIST.md` for the action plan.
---

## Addendum (Task 13.18 remediation)
C-1 (High) fixed: `canAccessPropertyDocument` now enforces document
visibility + allow-lists + real property relationships, fails closed, and covers
read/preview/download/signed-URL paths (21 regression tests pass). C-2 fixed
(signed-URL redemption re-authorizes). C-3 fixed (Pino redact). Provider
navigation dead-ends resolved (setup/operations reachable; Explore/Visits open
real screens). C-4 remains a documented MEDIUM (non-blocking). See
`TASK_13_18_RELEASE_GATE_REMEDIATION_REPORT.md`. Verdict moves to
READY FOR FINAL RELEASE REASSESSMENT.
