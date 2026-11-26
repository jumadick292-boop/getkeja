# Provider Category Operational Readiness — Audit (Task 13.11)

Evidence-based validation of every active service-provider category. No modules
were built; this is read-only audit plus a small set of verification runs.

## 1. Actual catalogue (live DB, not docs)
- **Service domains (enum `service_domain`, 18):** appliances, carpentry, cleaning,
  electrical, flooring, garbage, general, hvac, landscaping, laundry, moving,
  networking, painting, pest_control, plumbing, roofing, solar, tiling.
- **Categories (`service_categories`): 55**, all `is_active = true`.
- **Capabilities (`service_capabilities`): 62**, spanning all 18 domains.
- **Offerings (`provider_service_offerings`):** domain + category + `service_type`
  + `status` + `config`; capabilities via `provider_service_offering_capabilities`.
  The catalogue is domain-agnostic — offerings can be created for all 18 domains.
- **Four previously-requested categories present and separate:**
  `wifi_installation`, `internet_installation` (both `networking`),
  `solar_installation` (`solar`), `painting_decoration` (`painting`). Wi-Fi and
  Internet remain distinct; Solar and Painting remain distinct.

### Reconciliation
Migrations 107 (moving/garbage/laundry), 109 (cleaning/plumbing/electrical/hvac/
pest_control/landscaping/carpentry/painting/roofing/flooring/tiling/appliances/
general), 111 (networking/solar domains), 112 (wifi/internet/solar/painting
categories) seed the 55 categories. Live DB = 55 categories / 62 capabilities /
18 domains, matching the seeds (DB rebuilt from all 120 migrations). Flutter
discovery is backend-driven (`GET /api/v1/marketplace/categories`), so counts
match by construction; only 4 category labels + 3 domain labels are localized in
Flutter, the rest fall back to backend `name`.

## 2. Where the shared infrastructure stops
- **Shared marketplace flow works for all 18 domains**: create request
  (`marketplace.service.createRequest`, details via
  `detailsSchemaForCategory`), provider offering eligibility
  (`providerEligibleDomains`), quotation submit/revise/withdraw (immutable,
  versioned), atomic single-winner acceptance (`acceptQuotation`, row-locked),
  and a shared provider-driven `advanceJob` (`accepted → in_progress →
  completed`).
- **Strict per-category request validation** exists only for
  `wifi_installation`, `internet_installation`, `solar_installation`,
  `painting_decoration`, `garbage_*`, `laundry_*`. All other categories use the
  generic `serviceRequestDetailsSchema` (frequency/urgency/rooms/notes).
- **Dedicated operational modules exist only for moving, garbage, laundry**
  (`moving_jobs`, `garbage_jobs` (+ recurring agreements/occurrences),
  `laundry_orders`), each with lifecycle, staff assignments, scheduling,
  evidence/inspections, customer confirmation, notifications and contextual
  conversations. An accepted quotation does **not** auto-create a job; the
  provider calls a domain endpoint (`POST /api/v1/{moving,garbage}/provider/jobs`,
  `POST /api/v1/laundry/provider/orders`) guarded by accepted-quotation + ownership.
- **Scheduling** (`scheduling_activities`) supports only moving/garbage/
  garbage_occurrence/laundry (`scheduling.service.loadResource`; enum
  `scheduling_domain`). Other domains cannot be scheduled.
- **Contextual conversations** resolve `marketplace_request` (all domains),
  `moving_job`, `garbage_job`, `laundry_order`, `scheduling_activity`.
- **Notifications/outbox**: all domains emit `service_request.*`/`quotation.*`;
  ops domains add `moving_job.*`/`garbage_job.*`/`laundry_order.*`/`schedule.*`.

## 3. Readiness classification (definitions A/B/C/D)
- **Level A — Full operational module:** dedicated lifecycle + scheduling + staff +
  approvals + evidence + completion + customer confirmation, backend + Flutter.
- **Level B — Shared operational workflow:** requirements genuinely match an
  existing operational workflow; no separate module needed.
- **Level C — Marketplace only:** discovery/request/quotation/accept work, but no
  complete service-delivery workflow (no scheduling, staff, customer confirmation,
  or domain evidence).
- **Level D — Incomplete/defective:** missing/broken/inconsistent functionality
  that blocks reliable operation.

### Result
- **Level A — Full operational module (55 categories / 18 domains — all domains):**
  moving (10), garbage (10), laundry (13), Home Maintenance & Repairs (Task 13.12:
  plumbing (2), electrical (2), hvac (1), appliances (1), general (1), carpentry (1)),
  Cleaning & Property Care (Task 13.13: cleaning (3), pest_control (1),
  landscaping (2)), Installation & Technical Services (Task 13.14: networking
  (2: wifi_installation, internet_installation), solar (1: solar_installation)),
  plus Finishing & Building Services (Task 13.15: roofing (1), flooring (1),
  tiling (1), painting (2: painting, painting_decoration)) — a shared finishing
  ops module (inspections/measurements, work plans, materials/finishes, quality
  inspections, amendments, scheduling, staff, evidence, customer confirmation).
- **Level B (0 categories):** all operational domains now have a dedicated shared
  module; the generic `advanceJob` remains only a fallback and is not used to
  classify any category B.
- **Level C — Marketplace only (0 categories):** none remaining. (finishing moved
  to A in Task 13.15; networking/solar in 13.14; cleaning in 13.13; home
  maintenance in 13.12.)
- **Level D (0 categories):** no category is broken at the catalogue/request level.
  Cross-cutting UX gaps (home navigation stubs, scheduling detail nav limited to
  A domains, provider-side contact buttons, l10n coverage) are launch risks, not
  per-category defects — see report §14.

## 4. Security & authorization (verified)
- Marketplace: request ownership (`loadOwnedRequest`), single-winner acceptance
  with customer ownership check, provider domain isolation
  (`assertProviderCanQuote` + `providerEligibleDomains`).
- Ops domains: `assertProviderAccess` (owner profile always; else active assigned
  staff; org owner/admin bypass), `loadJobForCustomer`/`loadOrderForCustomer`
  enforce `customerUserId === userId`; revoked staff excluded.
- Conversations: participant universe derived server-side; cross-provider id swap
  denied; revoked staff denied (covered by `provider-communications.test.ts`).
- No category bypasses shared authz; no duplicate identity/org/scheduling/messaging
  systems found.

## 5. Test/verification evidence (this run)
- Server typecheck: clean. Migrations: `Pending: 0`. OpenAPI: 226 paths, valid.
- Vitest (marketplace, provider-catalogue, moving, garbage, laundry, scheduling,
  messaging incl. provider-communications): **80/80** across 8 files.
- Flutter `analyze`: **0 errors**. Seed counts: 55 cat / 62 cap / 18 dom / 4 mandatory.
- Per-category coverage gaps: only moving/garbage/laundry have lifecycle/staff/
  scheduling/approval/evidence tests; marketplace-only categories are covered only
  for request/quotation/accept, not delivery.

See `docs/reports/TASK_13_11_PROVIDER_CATEGORY_VALIDATION_REPORT.md` for the full
55-row table, module groups, sequencing, scope and launch blockers.