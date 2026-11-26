# GetKeja RMS — Comprehensive Audit (Task 14.0)

Evidence-based audit of the Rental Management System (RMS) implementation in the
existing GetKeja monorepo. Audit only — no RMS modules were implemented. All
findings cite the actual code/migrations; previous reports were not trusted.

Baseline: HEAD `b550497`; working tree 83 modified / 278 untracked (Tasks
13.15–13.19 preserved; no destructive git, no commits).

## 1. Architecture (unchanged)
Express 5 + TypeScript ESM + PostgreSQL (raw `pg`) + Redis + pg-boss + Zod +
Pino, REST under `/api/v1`. The RMS is implemented primarily inside the
**landlord** module (the de-facto RMS hub) plus **payments**, **tenancy**,
**rental-applications**, and the shared property/auth modules. No ORM, no
duplicate pools.

## 2. Database inventory (RMS-relevant)
Migrations: properties `039`, units `042`, tenancies `044`, rental_applications
`048`, tenants `070`, financial tables `078`, lease/inspection tables `080`.

- **Finance (`078`)** — `expense_categories`, `property_expenses`,
  `invoices` (invoice_number UNIQUE, billing period, due_date, total/amount_paid/
  amount_outstanding, currency), `invoice_items`, `payment_transactions`,
  `payment_allocations`, `rent_ledger_entries`, `tenant_deposits`,
  `deposit_transactions`. **All money is `DECIMAL(12,2)` with `currency CHAR(3)
  DEFAULT 'KES'` — no float/double money columns (verified).**
- **Lease/inspection (`080`)** — `rental_agreements` (status enum
  draft/pending_signature/active/renewed/terminated/expired/archived,
  start/end, deposit, `signed_by_tenant_at`, `signed_by_landlord_at`,
  `renewed_from_agreement_id`), `lease_documents`, `lease_renewal_records`,
  `lease_termination_records`, `move_in_inspections`, `move_out_inspections`,
  `inspection_items`, `move_out_inspection_items`.
- **Absent tables**: `leases` (only `rental_agreements`), `meters`/utility,
  `service_charges`, `rent_schedules`, `credit_notes`, `arrears`,
  periodic inspections, inventory/appliances.
- Constraints/indexes: invoices have 8 indexes + CHECKs (dates, totals ≥ 0);
  deposits/allocations/ledger have FK + CHECK (amount > 0) + indexes. FK
  integrity is generally good; `payment_allocations` and `property_expenses`
  exist but are **unused** (see §3).

## 3. Backend RMS status by area

### 3.1 Property & unit management — COMPLETE
Landlord routes: `/properties` CRUD, `/units` CRUD, `/properties/documents`.
Ownership (`property_ownerships`), assignments (`property_assignments`),
unit access (`unit_access_assignments`) with status checks. Portfolio = multiple
properties per owner/org. Flutter: `/landlord/properties*`.

### 3.2 Tenant & tenancy — PARTIAL
`createTenant` (landlord.controller:580) and a proposal-approval path
(landlord.controller:657) create tenant records; tenants are landlord-driven,
not created on public registration. Tenancy lifecycle via `tenancies` +
`tenancy_participants` (status active/removed). Gaps: no explicit onboarding
gate tying tenant creation to an *authorized* approval in all paths; historical
tenancies supported by table but no UI.

### 3.3 Lease management — PARTIAL
`rental_agreements` + `lease_documents` + renewal/termination records exist with
signature timestamps and status lifecycle. Landlord routes expose
`/rental-agreements` CRUD and `/lease-documents`. Gaps: no dedicated
sign/renew/terminate endpoints (only PATCH), no template management, no Flutter
lease screens. A tenancy is **not** treated as a signed lease (separate tables).

### 3.4 Rent billing & invoicing — PARTIAL
Invoices are **manually** created (`landlord.repository.createInvoice:2895`,
`POST /landlord/invoices`); payments consume invoices
(`payment.service.ts` locks invoice `FOR UPDATE`, updates paid/outstanding,
writes `rent_ledger_entries`, issues receipts). Gaps: **no recurring billing
worker** (only `mpesa-reconciliation.worker.ts`), no rent schedules, no
prorating, no credit notes, no invoice cancellation workflow, no numbering
automation beyond `PAY-`/invoice_number.

### 3.5 Ledger & tenant accounts — PARTIAL
`rent_ledger_entries` is written on invoice + payment (single-entry event log),
not double-entry. `payment_allocations` table is **unused (0 code refs)** —
payments update the invoice directly. No tenant balance/statement service beyond
payments endpoints. No refunds/overpayment/credit workflow.

### 3.6 Payment integration — COMPLETE (central model)
`payments` module: M-Pesa Daraja STK + central Paybill/Till + Pesapal, callbacks
(`/mpesa|/paybill|/till|/pesapal` + IPN), idempotency/duplicate-open-payment
guard, `mpesa-reconciliation.worker.ts`, reversals, deposits list. 55/55 payment
tests pass. No provider-specific tills. No real-money tests.

### 3.7 Arrears — MISSING
No arrears module/table/report. Outstanding is derivable from
`invoices.amount_outstanding`, but there is no aging, late-fee, reminder,
arrangement, waiver or notice workflow.

### 3.8 Expenses & accounting — MISSING
`property_expenses`/`expense_categories` tables exist but are **unused (0 code
refs)**; no expense API, no approvals, no receipts, no net-income computation.

### 3.9 Inspections & inventory — PARTIAL
Move-in/move-out inspections + items exist (DB + landlord routes). No periodic
inspections, no inventory/fittings/appliances, no key handover, no tenant
acknowledgment workflow.

### 3.10 Utilities & service charges — MISSING
No meter/utility/service-charge tables or modules. `charge_type` enum includes
`utility_charge`/`garbage_charge`/`service_charge` but nothing generates them.
Garbage is integrated via landlord `/garbage-*` routes, not via rent charges.

## 4. Integration matrix (existing → RMS)
| Module | RMS link | Status |
|---|---|---|
| Properties/units | landlord CRUD + ownership/assignments | COMPLETE |
| Rental applications | proposals → tenancy/tenant (landlord.controller:657) | PARTIAL |
| Tenancy | tenants/tenancy_participants | PARTIAL |
| Payments | invoices + central paybill/pesapal/mpesa | COMPLETE |
| Marketplace/ops (moving/garbage/laundry/maintenance/cleaning/install/finishing) | standalone job tables; garbage linked via landlord; others not linked to tenancy/property | DISCONNECTED |
| Scheduling | generic activities; inspections not scheduled via it | DISCONNECTED |
| Messaging/notifications | landlord conversations/issues; rent/lease reminders not automated | PARTIAL |
| Organizations/staff | property_assignments/unit_access with status | COMPLETE (authz) |
| Dashboard/reporting | landlord `/dashboard` + `/dashboard/extended` | PARTIAL |

## 5. Landlord financial reporting — PARTIAL
`getExtendedDashboardStats` (landlord.repository:3917) returns totalProperties,
units, occupied/vacant, listings, enquiries, activeTenancies, upcomingExpiries
(30d), pendingMaintenance, pendingGarbage, expectedRent, collectedRent,
outstandingRent. **Missing**: deposits held, expenses, net rental income,
arrears aging, lease-expiry revenue, maintenance spend, monthly/annual
comparisons, property/portfolio statements. Figures reconcile to invoices/
payments but not to allocations/expenses (unused).

## 6. Flutter RMS UX
- **Tenant**: `/tenant/dashboard`, tenancies(+detail), payments, invoices(+detail),
  methods, receipts, statement, deposits, maintenance, garbage/movers/laundries,
  notifications — PARTIAL/COMPLETE for payments.
- **Landlord**: `/landlord` dashboard, properties(+new/detail), listings,
  enquiries, proposals, site-visits, applications — but **no** invoices,
  tenants, leases, arrears, expenses, inspections, or financial-statement
  screens (backend exists, Flutter missing) → DISCONNECTED/PARTIAL.
- **Property manager / caretaker**: no dedicated RMS dashboards (caretaker authz
  exists for operations, not RMS).
- Localization: en/sw key sets identical; broad untranslated sw + hard-coded
  strings remain (documented).

## 7. Security & authorization
Landlord/property access via `canAccessProperty/Unit/Tenancy/Document`
(resource-scoped, status-checked); C-1 document authz fixed (21 tests). Tenant
payment initiation restricted to own tenancy (payment.service:145). Staff/caretaker
scoped by assignment status. Gaps: `payment_allocations`/`property_expenses`
unused so no allocation-level authz; no financial-change audit beyond ledger
inserts; IDOR covered by existing suites.

## 8. Coverage matrix
See `TASK_14_0_RMS_AUDIT_REPORT.md` §9 for the full feature/status/gap/next-task
matrix. Status legend: COMPLETE / PARTIAL / DISCONNECTED / MISSING / NOT VERIFIED.

## 9. Completion estimate (RMS-specific)
Method: 14 equally-weighted RMS capability areas; score COMPLETE=1.0,
PARTIAL=0.5, DISCONNECTED=0.25, MISSING=0. Average ≈ **50%**. This deliberately
excludes generic property/payment infrastructure from counting as complete RMS
workflows. See report for the per-area scoring.