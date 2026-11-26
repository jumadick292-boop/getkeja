# GetKeja Service Provider Platform — Implementation Roadmap (Tasks 13.2–13.12)

**Repository:** `get-keja-repo`
**Prerequisite:** Task 13.1 Architecture Audit (`docs/architecture/service-provider-platform-audit.md`) — complete.
**Backend:** `server/` (Express 5, TypeScript ESM, PostgreSQL, Redis). **Flutter:** `Mobile/` (Riverpod, Dio, GoRouter).

> This roadmap starts from the **verified** state in the audit: tenant request **create/cancel already exist**; provider-facing platform, discovery-over-HTTP, quotations, jobs, payouts, and provider Flutter are missing. The System Design Blueprint covers **moving + garbage**; **laundry is an approved extension**. Blueprint out-of-scope items (fleet management, route optimization, driver management, automated collection logistics, quality/price guarantees) are **excluded** from MVP and deferred.

---

## 1. Provider Account & Organization Model

- **One identity, many roles.** A person uses one GetKeja login; provider capability is an additive `specialized_profiles` row (`profile_category` ∈ moving/garbage/laundry) plus optional `organisations` membership. No second auth system, no duplicate org tables.
- **Individual providers:** independent mover / garbage operator / laundry operator (profile only).
- **Provider organizations:** `organisations.type` ∈ `moving_company | garbage_collection | laundry | other`; multi-service via multiple profiles/domains (added safely in 13.4).
- **Staff roles (additive to `owner|admin|member|staff`):** owner, admin, supervisor/ops, dispatcher, operational staff, finance. Permissions are org-global, domain-scoped, or assignment-scoped (see audit §6).
- **Hard boundaries:** org membership never grants blanket customer-request access; landlords/PMs/caretakers never auto-gain provider rights; a provider profile never grants property/tenancy access.

---

## 2. Domain Summaries (target)

### 2.1 Moving
Profile (individual/business, service types, coverage, operating hours, insurance/certs). Request: pickup (saved home **or** temporary address — distinct), destination (temporary), preferred datetime, inventory, photos, contact. Quotation + negotiation (≤3 rounds). Lifecycle `submitted→pending_confirmation→accepted→scheduled→in_progress→completed` (+ declined/cancelled/disputed). Completion evidence + rating.

### 2.2 Garbage
Profile (individual/business/org; categories; schedules; plans). Property/unit association via `garbage_provider_assignments`. Request types: regular/special/bulky/recycling/missed. Recurring via **template** (no auto-duplicate). Provider change: landlord-initiated → approval → effective-date transition. Lifecycle `submitted→acknowledged→scheduled→in_progress→completed` (+ rescheduled/missed/disputed).

### 2.3 Laundry (extension)
Profile (operator/business; wash/dry/iron/etc.; per-kg/item/bundle pricing; turnaround). Request: items, pickup/delivery, schedule. Optional weight-based quote. Lifecycle `submitted→pending_confirmation→accepted→scheduled→picked_up→in_progress→ready_for_delivery→delivered→completed` (+ declined/cancelled/quality_dispute). **Distinct lifecycle — not forced into mover/garbage shape.**

---

## 3. Shared Infrastructure & Boundaries

Reuse: `specialized_profiles`(+extensions, laundry services), `provider_service_areas`, `saved_locations`, verification, `organisations`/`organisation_members`, `authorization.service`, transactional outbox, `messaging`, payments tables, design system/l10n.

Build a **thin shared layer** over existing tables (do not drop them): `service-requests` service/repository + per-domain `status-transitions.ts` + assignment + notifications.

| Share | Keep domain-specific |
|-------|----------------------|
| Identity, customer/property/unit linkage, status history, assignment, notifications, messaging, attachments, ratings, disputes, invoicing | Moving quotation/inventory; Garbage recurring/provider-change; Laundry pickup/delivery/facility |

---

## 4. Location & Privacy

Reuse `saved_locations` types (`personal_residential`, `business_office`, `provider_operating`, `service_area`, `property_location`) and `provider_service_areas` (county/town/neighbourhood + lat/lng + radius). MVP = text + radius matching (wire the existing Haversine repo over HTTP); maps are V2 with text fallback. **No continuous tracking.** Any future live tracking is opt-in, time-boxed to an active job. Customer residential coordinates are never shown to unrelated providers.

---

## 5. Financial Boundaries

Central collections only (M-Pesa Daraja + Pesapal); **no provider Paybills/Tills**, no duplicate ledger. Flow: quotation/estimate → draft invoice on acceptance → customer payment via existing adapters → allocation to invoice → commission rule → provider earning (record) → batch payout (future). **This roadmap does not implement payment processing or payouts**; it defines `provider_payouts`, `payout_transactions`, `provider_commission_rules` as future tables and read-only earnings from existing tables. Receiving a customer payment ≠ provider paid out.

---

## 6. Security & Authorization (per operation)

Every provider/tenant operation requires: authentication + permission + scope check (org / provider / customer ownership / property/tenancy / assignment). IDOR prevention via UUIDs + mandatory `authorize()` before DB access; no "access by id alone." Cross-org and cross-provider isolation enforced on every org/assignment-scoped call. Caretakers/landlords scoped to their properties; provider data visibility rules per audit §9.

---

## 7. Flutter Provider Experience (target)

Bottom-nav provider app: **Dashboard** (profile completion, verification, new requests, pending quotes, upcoming/active/completed jobs, performance), **Requests/Jobs** (inbox, detail, quotation builder, status flow, completion), **Schedule**, **Organization** (staff invite/roles/domain matrix, job assignment, org profile), **Profile** (identity, services, areas, hours, verification, documents), **Earnings** (read-only), **Communications** (per-job chat, notifications), **Settings** (EN/SW). Every screen maps to a real `/api/v1/provider` endpoint + permission — no static/demo data.

---

## 8. Database & API Blueprint (summary)

New tables (future migrations, after 13.2 foundation): `service_quotations`, `service_jobs`, `job_status_history` (or reuse existing history tables), `recurring_collection_templates`, `service_request_messages` (or reuse `messaging`), `service_ratings`, `service_disputes`, `provider_payouts`, `payout_transactions`, `provider_commission_rules`. Modify: converge `garbage_providers`→`specialized_profiles` (backfill), add `provider_type` to profiles, `service_domains` to orgs. API groups: `/api/v1/tenant/*` (add missing GETs), `/api/v1/provider/*` (dashboard, requests, quotes, jobs, schedule, earnings, profile, service-areas, organization/staff), `/api/v1/landlord/*` (provider change), `/api/v1/public/providers/*` (discovery). Full catalogue in the audit/this roadmap history.

---

## 9. Implementation Sequence

### 13.2 — Shared Provider Domain Foundation & Authorization
**Scope:** shared request layer + missing GETs + discovery HTTP + authz + outbox classification.
**Deps:** none. **Backend:** add `GET /tenant/moving-requests`, `GET /tenant/laundry-requests`; `service-requests` service/repo over existing 3 tables; `status-transitions.ts`; expose `provider-discovery` via `GET /api/v1/public/providers/:category`; provider/assignment authz helpers. **DB:** none (reuse). **Flutter:** verify datasources post-fix; add role guard scaffolding. **Authz:** provider/assignment scope. **Tests:** vitest for new GETs, transitions, discovery, authz. **Docs:** OpenAPI. **Acceptance:** tenant list/create/cancel works for all 3; discovery reachable; transition matrix enforced; tests green.

### 13.3 — Provider Profiles, Organizations & Staff
**Deps:** 13.2. Provider profile completion API; org staff invite + role/domain matrix; verification admin review + suspension. **DB:** `provider_type`, org `service_domains`, staff domain scoping; converge `garbage_providers`. **Flutter:** provider profile + org staff screens. **Tests:** invite/permission matrix.

### 13.4 — Service Catalogues, Locations & Service Areas
**Deps:** 13.2, 13.3. Moving catalogue, garbage plans, laundry pricing; operating hours; service-area CRUD + text/radius matching (maps V2). **Flutter:** service config + area picker.

### 13.5 — Shared Request & Quotation Infrastructure
**Deps:** 13.2, 13.3. Moving quotation + counter-offer; assignment to provider org; outbox events for full lifecycle; request chat (reuse `messaging`). **DB:** `service_quotations`, reuse messaging. **Flutter:** quotation builder, live inbox, chat.

### 13.6 — Moving Provider Platform
**Deps:** 13.2, 13.5. Crew/vehicle assignment, inventory, status flow, completion evidence, disputes (damage/missing/delay). **DB:** moving extension fields. **Flutter:** moving job mgmt + completion. (No route optimization/fleet per blueprint.)

### 13.7 — Garbage Collection Provider Platform
**Deps:** 13.2, 13.5. Recurring templates (no auto-duplicate), missed-collection, provider-change workflow, collection evidence. **DB:** `recurring_collection_templates`, change history. **Flutter:** schedule calendar, missed reporting, provider-change UI.

### 13.8 — Laundry Provider Platform
**Deps:** 13.2, 13.5. Pickup/delivery + driver assignment, facility processing tracking, quality check, subscription plans. **DB:** laundry extension. **Flutter:** job board, facility dashboard, quality check.

### 13.9 — Scheduling, Assignments & Operational Management
**Deps:** 13.6–13.8. Dispatcher dashboard, assignment rules (nearest/workload/skills), capacity/standby. (Route optimization deferred — blueprint out of scope.) **Flutter:** dispatcher assignment.

### 13.10 — Communications, Notifications & Customer Experience
**Deps:** 13.5, 13.6–13.8. FCM/push, notification preferences, customer tracking, automated status updates, reminders. **DB:** preferences/device tokens.

### 13.11 — Dashboards, Reporting, Reviews & Complaints
**Deps:** 13.6–13.10. Earnings dashboard (read-only from existing tables), performance metrics, bidirectional ratings, dispute workflow, admin oversight. **DB:** `service_ratings`, `service_disputes`, read models. Payout **tables defined**, disbursement deferred.

### 13.12 — Full Security, Integration & Release Audit
**Deps:** all. Authz/IDOR/injection/secrets audit; load test; Kenya DPA 2019 compliance; backup/restore; OpenAPI complete; rollback runbooks. **Flutter:** cert pinning, secure storage, a11y (WCAG 2.2 AA), EN/SW QA, release builds. **Acceptance:** tests pass, security sign-off, perf targets, docs complete.

---

## 10. Test & Release Strategy

Backend: vitest (unit 80%, integration 70%, **authz 100% of matrix**, repos 80%). Flutter: flutter_test (unit 80%, widget/golden 60%, integration critical paths). Gates: dev→staging (tests + OpenAPI + migrations clean), staging→prod (security + load + QA + docs), post-release (error <0.1%, p95 <500ms, zero critical authz failures). Rollback: down migrations, `FEATURE_PROVIDER_PLATFORM` flag, blue-green 48h, idempotent backfills.

---

## 11. Risk Register (top)

Maps unavailable→text/radius fallback; M-Pesa B2C limits→batch/manual; verification fraud→doc validation + re-verification; cross-domain authz bugs→100% matrix tests; recurring duplicates→idempotent templates; tracking privacy→opt-in/time-boxed/audit; multi-service org complexity→single-domain first; Kenya DPA→legal review + minimization.

---

## 12. Success Metrics

Request→assignment <30min moving / <15min garbage+laundry; onboarding→verified <48h; completion >95%; rating >4.2/5; payout accuracy 100%; uptime 99.9%; authz coverage 100%; zero critical security findings.

---

## 13. Recommended Next Action

**Begin Task 13.2** only after audit + roadmap approval. First concrete step: add the missing `GET` list endpoints and the shared `service-requests` service/repository/status-transition layer, then expose provider discovery over HTTP.