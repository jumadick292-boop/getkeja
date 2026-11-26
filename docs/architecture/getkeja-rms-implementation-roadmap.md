# GetKeja RMS — Implementation Roadmap (Task 14.0)

Prioritized, dependency-aware plan to complete the RMS. Mandatory capabilities
first; advanced/optional later. Each task lists scope, dependencies, DB/backend/
Flutter impact, integrations, security, acceptance, tests. No ORM/microservices;
additive migrations only; money `DECIMAL(12,2)` + currency; central payment model
preserved.

## Mandatory RMS capabilities

### Task 14.1 — Recurring rent billing & invoice generation
- Scope: rent schedules per tenancy, pg-boss recurring generator, invoice
  numbering, billing periods, due dates, prorating, duplicate-invoice protection,
  missed-job catch-up, Africa/Nairobi timezone.
- Dependencies: tenancies, invoices (078).
- DB: add `rent_schedules` (+ indexes); reuse `invoices`/`invoice_items`.
- Backend: new `billing` module + pg-boss worker; idempotent `(tenancy, period)`.
- Flutter: landlord invoice list/detail; tenant invoice list (exists) + detail.
- Integrations: notifications (rent due), payments (consume invoices).
- Security: landlord/manager scoped to assigned properties; tenant own invoices.
- Acceptance: recurring invoice created once per period; restart safe; proration.
- Tests: unit (schedule/proration), integration (worker idempotency), Flutter.

### Task 14.2 — Payment allocation & ledger completion
- Scope: allocate payments across invoices via `payment_allocations`; tenant
  account balance; overpayment/credit; refunds; double-entry `rent_ledger_entries`.
- Dependencies: 14.1, payments.
- DB: use existing `payment_allocations`; add balance view/entries as needed.
- Backend: allocation service + tenant balance endpoint.
- Flutter: tenant account balance + statement (extend existing).
- Security: allocation authz; tenant own; staff permissions.
- Acceptance: balances reconcile to allocations; no double counting.
- Tests: allocation math, overpayment, refund, reconciliation.

### Task 14.3 — Arrears management
- Scope: overdue derivation from invoices, aging buckets, late fees, reminders,
  arrangements, waivers, disputes, notices, arrears report.
- Dependencies: 14.1/14.2.
- DB: `arrears_notices`/`payment_arrangements`/`late_fee_rules` (additive).
- Backend: arrears service + report; notification triggers.
- Flutter: landlord arrears screen; tenant notices.
- Security: waivers/approvals permissioned; audit.
- Acceptance: arrears derived (not manual), aging correct.
- Tests: aging, late fee, arrangement, waiver audit.

### Task 14.4 — Expenses & property accounting
- Scope: property/unit expenses, categories, suppliers, approvals, receipts,
  recurring, payments; income/expenditure; net rental income.
- Dependencies: 14.1/14.2.
- DB: use `property_expenses`/`expense_categories` (add supplier/approval cols).
- Backend: expense module + approval + recurring.
- Flutter: landlord expenses + net income.
- Security: approval permissions; receipt authz.
- Acceptance: net income = collected − expenses; reconcilable.
- Tests: expense CRUD/approval, net income.

### Task 14.5 — Landlord statements & financial reporting
- Scope: property/portfolio statements, monthly/annual comparisons, deposits
  held, maintenance spend, lease-expiry revenue.
- Dependencies: 14.1–14.4.
- Backend: extend `/dashboard/extended` + statements endpoints.
- Flutter: landlord reports/statements.
- Acceptance: figures reconcile to invoices/allocations/expenses.
- Tests: statement totals vs source.

### Task 14.6 — Lease lifecycle completion + Flutter
- Scope: sign/renew/terminate/amend endpoints, templates, signature evidence,
  status history; Flutter lease screens.
- Dependencies: rental_agreements (080).
- Backend: lease service endpoints; DB: use 080 tables.
- Flutter: landlord lease list/detail; tenant lease detail.
- Security: document authz (C-1); signature evidence.
- Acceptance: full lifecycle; signed doc gated.
- Tests: lifecycle transitions, authz.

### Task 14.7 — Utilities & service charges
- Scope: meters, readings, consumption, shared allocation, utility/garbage/
  security charges on invoices.
- Dependencies: 14.1.
- DB: `meters`/`meter_readings`/`service_charge_rules` (additive).
- Backend: utility service; integrate garbage ops.
- Flutter: tenant utility bills; landlord utility config.
- Acceptance: consumption-based charges correct.
- Tests: reading→charge, allocation.

### Task 14.8 — Periodic inspections & inventory
- Scope: periodic inspections, checklists, condition reports, inventory/
  fittings, key handover, tenant acknowledgment.
- Dependencies: 080 move-in/out.
- DB: `periodic_inspections`/`inventory_items` (additive).
- Backend: inspection service + scheduling integration.
- Flutter: landlord/caretaker inspections; tenant acknowledgment.
- Acceptance: scheduled + acknowledged.
- Tests: lifecycle, scheduling link.

### Task 14.9 — Property-manager & caretaker RMS dashboards
- Scope: assigned-property dashboards, permission-limited financial access.
- Dependencies: authz (exists), 14.4/14.5.
- Flutter: PM/caretaker dashboards.
- Security: assignment-scoped; least privilege.
- Acceptance: only assigned resources; no cross-property.
- Tests: authz matrix.

### Task 14.10 — Ops ↔ tenancy/property linkage
- Scope: link moving/garbage/laundry/maintenance/cleaning/installation/finishing
  jobs to property/unit/tenancy; tenant move-in/out coordination.
- Dependencies: ops modules (exist).
- DB: add property/unit/tenancy refs where missing (additive).
- Backend: link on job creation.
- Flutter: surface linked jobs in tenant/landlord views.
- Acceptance: jobs associated; no duplicate systems.
- Tests: linkage + authz.

## Advanced / optional
- Agent commissions & advanced analytics (after 14.5).
- Multi-currency expansion (schema already has currency).
- Automated dunning/collections, credit scoring.
- Mobile push for rent/lease events.

## Cross-cutting requirements (all tasks)
- Additive, idempotent migrations; fresh + existing DB verified.
- Money `DECIMAL(12,2)` + explicit currency (KES default, not assumed).
- Resource-scoped authz (owner/manager/caretaker/tenant), IDOR tests.
- Audit trail for financial mutations.
- EN/SW localization; loading/empty/error states.
- No real-money tests; sandbox/mocks only.