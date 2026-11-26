# Task 14.0 — RMS Audit Report

## 1. Baseline
HEAD `b550497`; 83 modified / 278 untracked (13.15–13.19 preserved). No
destructive git; no commits. Verification: `tsc --noEmit` clean; OpenAPI 319
paths / 0 dangling; migrations pending 0.

## 2. Actual existing RMS implementation
The RMS is **partially implemented**, centred on the **landlord** module
(properties, units, tenants, listings, enquiries, rental-proposals, invoices,
payments, rent-ledger, issues, rental-agreements, lease-documents, move-in/out
inspections, dashboard/extended) plus **payments** (central Paybill/Till +
Pesapal + M-Pesa Daraja) and **tenancy/rental-applications**. Finance and lease
tables exist (migrations 078/080) with correct `DECIMAL(12,2)` + currency.

## 3. Fully integrated capabilities
- Property & unit management (+documents, ownership/assignments). COMPLETE.
- Central payment collection (STK/Paybill/Till/Pesapal, callbacks, idempotency,
  reconciliation, reversals). COMPLETE (55/55 tests).

## 4. Partially integrated capabilities
- Tenant/tenancy lifecycle (landlord-driven; onboarding gate not uniform). PARTIAL.
- Lease management (rental_agreements + docs + renewal/termination tables; no
  sign/renew/terminate endpoints; no Flutter). PARTIAL.
- Rent invoicing (manual create; payments consume; **no recurring billing**). PARTIAL.
- Ledger (single-entry `rent_ledger_entries`; `payment_allocations` unused). PARTIAL.
- Deposits (tables + tenant list; limited workflow). PARTIAL.
- Inspections (move-in/out only; no periodic/inventory). PARTIAL.
- Landlord dashboard (occupancy + expected/collected/outstanding; no
  deposits/expenses/net/arrears/statements). PARTIAL.
- Flutter tenant payments/invoices/deposits/statement. PARTIAL.
- Messaging/notifications (conversations/issues; no automated rent/lease
  reminders). PARTIAL.

## 5. Missing capabilities
- Recurring rent billing / rent schedules / proration / credit notes.
- Arrears management (aging, late fees, reminders, arrangements, waivers, notices).
- Expenses & property accounting (tables unused; no API; no net income).
- Utilities & service charges (meters, readings, allocation).
- Periodic inspections, inventory/fittings, key handover.
- Landlord financial statements (property/portfolio), monthly/annual comparisons.
- Flutter landlord invoices/tenants/leases/arrears/expenses/inspections/statements;
  property-manager & caretaker RMS dashboards.

## 6. Security gaps
Existing resource-scoped authz + C-1 fix are solid. Gaps: unused
`payment_allocations`/`property_expenses` mean no allocation/expense-level authz
or audit; no financial-mutation audit beyond ledger inserts; no automated
reminders (no notification triggers for rent/lease).

## 7. Database gaps
No `leases`(only rental_agreements)/meters/service_charges/rent_schedules/
credit_notes/arrears/periodic-inspection/inventory tables. `payment_allocations`
and `property_expenses` orphaned (unused). Money precision/currency correct.
Recommend additive migrations only.

## 8. Flutter gaps
Landlord RMS financial/lease/expense/inspection screens absent; PM/caretaker RMS
dashboards absent; broad sw/hard-coded l10n gaps.

## 9. RMS coverage matrix
| # | Feature | Backend | DB | Flutter | Integrations | Tests | Status | Key gap | Next task |
|---|---|---|---|---|---|---|---|---|---|
|1|Property/unit mgmt|landlord|039/042|/landlord/properties*|ownership/assign|landlord.test|PASS|COMPLETE|—|
|2|Tenant/tenancy|landlord,tenancy|044/070|/tenant/tenancies*|proposals→tenant|tenancy.test|PASS|PARTIAL|uniform onboarding gate|
|3|Lease mgmt|landlord(rental-agreements,docs)|080|none|payments(no rent link)|landlord.test|PASS|PARTIAL|sign/renew/terminate + Flutter|
|4|Rent billing/invoices|landlord(create),payments(consume)|078|/tenant/payments/invoices*|payments|PASS|PARTIAL|recurring worker, proration, credit notes|
|5|Ledger & allocation|payments(ledger)|078|tenant statement|payments|PASS|PARTIAL|use payment_allocations; double-entry|
|6|Payment integration|payments|078/078+|tenant payments|central|PASS|COMPLETE|—|
|7|Deposits|payments list|078|/tenant/payments/deposits|payments|PASS|PARTIAL|create/refund workflow|
|8|Arrears|none|none|none|none|NOT VERIFIED|MISSING|full module|
|9|Expenses/accounting|none|078(unused)|none|none|NOT VERIFIED|MISSING|expense API + net income|
|10|Inspections/inventory|landlord(move-in/out)|080|none|scheduling(no)|landlord.test|PASS|PARTIAL|periodic + inventory|
|11|Utilities/charges|none|none|none|garbage(landlord)|NOT VERIFIED|MISSING|meters + allocation|
|12|Landlord reporting|landlord /dashboard/extended|078/080|/landlord dashboard|payments|landlord.test|PASS|PARTIAL|deposits/expenses/net/statements|
|13|Flutter RMS UX|various|various|tenant yes/landlord partial|—|flutter 244/244|PARTIAL|landlord financial/lease screens; PM/caretaker|
|14|Ops integrations|ops modules|job tables|ops pages|standalone|ops suites|PASS|DISCONNECTED|link jobs to tenancy/property|

## 10. Completion % (methodology)
14 equally-weighted RMS areas; COMPLETE=1.0, PARTIAL=0.5, DISCONNECTED=0.25,
MISSING=0. Scores: 1.0+0.5+0.5+0.5+0.5+1.0+0.5+0+0+0.5+0+0.5+0.5+0.25 = 6.75
/ 14 ≈ **48%**. Generic property/payment infra is intentionally not counted as
complete RMS. Unweighted by feature count to avoid inflating with infra.

## 11. Recommended sequence & exact next task
Sequence: (1) recurring rent billing + invoices, (2) payment allocation +
ledger completion, (3) arrears, (4) expenses + landlord statements, (5) lease
sign/renew/terminate + Flutter, (6) utilities, (7) periodic inspections/inventory,
(8) PM/caretaker dashboards, (9) ops→tenancy linkage.
**Exact next implementation task: Task 14.1 — Recurring rent billing & invoice
generation (pg-boss rent scheduler, rent_schedules, prorating, idempotency),
with invoice create/list/detail Flutter for landlord and tenant.**

## 12. Verification executed
`tsc --noEmit` (clean); OpenAPI 319/0; migrate pending 0; backend suites green
(13.19: 127+219+25 files); Flutter analyze 0, 244/244. No DB mutations.