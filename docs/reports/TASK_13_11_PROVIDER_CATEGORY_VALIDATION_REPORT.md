# Task 13.11 — Provider Category Operational Readiness Validation Report

Validation only. No operational modules were built. No accepted quotations,
identities, scheduling, messaging or authorization were changed. No commits.

## 1. Actual counts
- Domains: **18**. Categories: **55** (all active). Capabilities: **62**.
- Mandatory four present & separate: `wifi_installation`, `internet_installation`,
  `solar_installation`, `painting_decoration`.

## 2. Complete category inventory (55) with classification
All categories in a domain share that domain's operational capability, so each
domain's categories share a level. "Shared marketplace" = request+offering+quote+
accept+`advanceJob` works; "Ops module" = dedicated lifecycle+scheduling+staff+
approvals+evidence+customer confirmation.

| # | Domain | Category id | Name | Level |
|---|--------|-------------|------|-------|
| 1 | moving | moving_apartment | Apartment moving | A |
| 2 | moving | moving_appliance | Appliance transport | A |
| 3 | moving | moving_commercial | Commercial moving | A |
| 4 | moving | moving_furniture | Furniture transport | A |
| 5 | moving | moving_household | Household moving | A |
| 6 | moving | moving_loading | Loading and unloading | A |
| 7 | moving | moving_local | Local moving | A |
| 8 | moving | moving_long_distance | Long-distance moving | A |
| 9 | moving | moving_office | Office moving | A |
| 10 | moving | moving_packing | Packing and unpacking | A |
| 11 | garbage | garbage_estate | Apartment/estate collection | A |
| 12 | garbage | garbage_bulk | Bulk waste collection | A |
| 13 | garbage | garbage_bulky | Bulky waste pickup | A |
| 14 | garbage | garbage_commercial | Commercial waste collection | A |
| 15 | garbage | garbage_household | Household garbage collection | A |
| 16 | garbage | garbage_one_time | One-time collection | A |
| 17 | garbage | garbage_organic | Organic / green waste | A |
| 18 | garbage | garbage_recycling | Recycling collection | A |
| 19 | garbage | garbage_residential | Residential waste collection | A |
| 20 | garbage | garbage_scheduled | Scheduled collection | A |
| 21 | laundry | laundry_bedding | Bedding and linen cleaning | A |
| 22 | laundry | laundry_commercial | Commercial laundry | A |
| 23 | laundry | laundry_dry_clean | Dry Cleaning | A |
| 24 | laundry | laundry_dry_cleaning | Dry cleaning | A |
| 25 | laundry | laundry_drying | Drying | A |
| 26 | laundry | laundry_folding | Folding | A |
| 27 | laundry | laundry_textile | Household Textiles | A |
| 28 | laundry | laundry_household | Household laundry | A |
| 29 | laundry | laundry_ironing | Ironing | A |
| 30 | laundry | laundry_iron_only | Ironing & Pressing | A |
| 31 | laundry | laundry_pickup_delivery | Pickup and delivery | A |
| 32 | laundry | laundry_wash_fold | Wash & Fold | A |
| 33 | laundry | laundry_washing | Washing | A |
| 34 | cleaning | clean_deep | Deep cleaning | A |
| 35 | cleaning | clean_home | Home cleaning | A |
| 36 | cleaning | clean_office | Office cleaning | A |
| 37 | plumbing | plumbing_emergency | Emergency plumbing | A |
| 38 | plumbing | plumbing_general | Plumbing | A |
| 39 | electrical | electrical_general | Electrical | A |
| 40 | electrical | electrical_wiring | Wiring and rewiring | A |
| 41 | hvac | hvac_service | HVAC service | A |
| 42 | pest_control | pest_control_general | Pest control | A |
| 43 | landscaping | gardening | Gardening | A |
| 44 | landscaping | landscaping_general | Landscaping | A |
| 45 | carpentry | carpentry | Carpentry | A |
| 46 | painting | painting | Painting | A |
| 47 | painting | painting_decoration | Painting & Decoration | A |
| 48 | roofing | roofing | Roofing | A |
| 49 | flooring | flooring | Flooring | A |
| 50 | tiling | tiling | Tiling | A |
| 51 | appliances | appliance_repair | Appliance repair | A |
| 52 | general | handyman | Handyman | A |
| 53 | networking | internet_installation | Internet Installation & Connectivity | A |
| 54 | networking | wifi_installation | Wi-Fi Installation & Configuration | A |
| 55 | solar | solar_installation | Solar Installation & Maintenance | A |

Totals: **A = 53** (18 domains — all domains; incl. Home Maintenance 13.12 + Cleaning 13.13 + Installation 13.14 + Finishing 13.15), **B = 0**, **C = 0**, **D = 0**.

## 3. Evidence summary
- **DB:** only moving/garbage/laundry have operational tables; all 18 have
  categories/capabilities; `scheduling_domain` enum = moving/garbage/
  garbage_occurrence/laundry.
- **Backend:** shared marketplace (request/offering/quote/accept/advanceJob) for
  all 18; strict detail schemas for 6 named categories + garbage/laundry prefixes;
  ops modules + scheduling + staff + approvals + evidence only for A domains.
- **Flutter:** generic discovery + request form (special fields for
  wifi/internet/solar/painting) + generic provider offering for all; ops screens
  only for A domains; scheduling detail nav only for A domains; contact buttons on
  A-domain + marketplace customer pages; l10n for 4 categories + 3 domains.
- **E2E:** A domains complete the full 8-step customer + 8-step provider journey.
  C domains complete steps 1–4 (discover/request/quote/accept) and a provider-driven
  `advanceJob` completion, but lack scheduling, staff assignment, customer approval
  and domain evidence (steps 5–8 partial).

## 4. Security findings
No category unsafe at the request/marketplace layer. Ops authz (owner/assigned/
revoked/cross-provider) verified for A domains and for conversations. No duplicate
systems. No authorization weakening.

## 5. Test coverage & failures
- Typecheck clean; migrations pending 0; OpenAPI 226 paths valid.
- Backend 80/80 (marketplace, catalogue, moving, garbage, laundry, scheduling,
  messaging+provider-communications). Flutter analyze 0 errors.
- Coverage gap: C domains have no delivery-lifecycle tests (none exist to run).
- Pre-existing unrelated: `auth/notification.test.ts` cleanup is not FK-complete
  (passes only on a clean DB) — not touched.

## 6. Missing operational capabilities (C domains)
Dedicated lifecycle table, domain staff assignment, scheduling, customer
confirmation/approval, domain evidence/inspections, completion-submission flow,
domain Flutter detail/progress screens, scheduling detail navigation, domain l10n.

## 7. Recommended operational module groups
1. **Home maintenance & repairs** — plumbing, electrical, hvac, appliances,
   general(handyman), carpentry. Shared "service visit" engine: schedule → assign →
   arrive → work → evidence → customer confirm. Differences: emergency (plumbing),
   appliance diagnostics, electrical safety evidence. One shared engine appropriate.
2. **Cleaning & property care** — cleaning, pest_control, landscaping, (water tank
   cleaning if added). Shared recurring/one-off visit engine with checklist +
   before/after evidence. One shared engine appropriate.
3. **Installation & technical** — wifi, internet, solar, (security/CCTV if added).
   Shared "installation" engine: site assessment → schedule → install → test/accept
   → handover. Solar needs assessment + inspection; wifi/internet need test evidence.
   One shared engine with per-category config fields (already have strict schemas).
4. **Finishing & building** — painting, roofing, flooring, tiling. Shared "project"
   engine: measure/quote-confirm → schedule → work in stages → inspection → customer
   approval → completion. Painting/roofing need staged progress + weather/area notes.
   One shared engine appropriate.

Moving/garbage/laundry already dedicated (A); confirm scheduling + comms integration
(already wired). Each proposed group needs: lifecycle states, staff assignment,
scheduling (extend `scheduling_domain` enum + `loadResource`), customer
confirmation, evidence tables, domain Flutter screens, l10n, and tests.

## 8. Proposed implementation sequence
1. Group 1 (maintenance) — highest volume, simplest shared engine.
2. Group 2 (cleaning/property care) — reuses visit engine + checklists.
3. Group 3 (installation) — reuse strict schemas; add assessment/handover.
4. Group 4 (finishing) — staged project engine (most complex).
Each group: extend scheduling enum + `loadResource`, add lifecycle/evidence/staff
tables, Flutter detail screens, l10n, tests. Await approval before building.

## 9. Scope & dependencies per group
- Shared prerequisite: extend `scheduling_domain` enum + `scheduling.service.loadResource`
  + Flutter scheduling nav (currently hardcoded to A domains) + provider-side contact
  buttons + home navigation to /marketplace & /scheduling.
- Group 1: ~1 lifecycle + staff + evidence + 2 Flutter screens + l10n + tests.
- Group 2: visit engine + checklist/evidence + recurring option.
- Group 3: assessment + handover + test evidence; reuse existing strict schemas.
- Group 4: staged project + inspection + approval; largest.

## 10. Launch blockers & risks
- C domains cannot be scheduled, staffed, or customer-confirmed → not deliverable
  end-to-end today (blocker for launch as "operational").
- Home UI has no navigation to /marketplace or /scheduling (tiles are stubs);
  discovery reachable only via deep link/direct route.
- Scheduling detail navigation + provider contact buttons limited to A domains.
- l10n covers only 4 categories + 3 domains; other categories show backend names.
- `scheduling_domain` enum + `loadResource` must be extended per group (DB + code).
- Do not ship C domains as "operational" until a shared engine (B) is built and
  verified; until then they are marketplace-only (quote-and-complete via advanceJob,
  no scheduling/confirmation).

## 11. Definition-of-done status
Every active category has an evidence-based classification (A/B/C/D) and the
remaining work is mapped into four implementation groups with sequence, scope,
dependencies and blockers. Implementation of the remaining modules has NOT started;
awaiting approval of this report.