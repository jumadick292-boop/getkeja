# Maintenance, Garbage Services & Financial Reporting — Implementation

**Repository:** `get-keja-repo`
**Backend:** `server/` (Node.js/Express/PostgreSQL)
**Flutter app:** `Mobile/` (Flutter 3.50.0, Riverpod 3, Dio, GoRouter)
**Feature:** Landlord-side property issue/maintenance intake, garbage provider & collection management, and dashboard financial reporting

## 1. Overview

Landlords manage property upkeep and services from the backend. This covers three domains:

- **Maintenance** — issue intake (`property_issues`) with category/priority/status lifecycle.
- **Garbage services** — providers, property/unit assignments, and collection requests.
- **Financial reporting** — dashboard aggregates (occupancy, enquiries, tenancies, and computed rent figures) plus invoice/payment/ledger CRUD.

## 2. Maintenance

### Scope

Maintenance issue intake is implemented. The `maintenance_requests` tables and Zod schemas exist (`createMaintenanceRequestSchema`, `updateMaintenanceRequestSchema`) but **no HTTP routes are registered** for them yet; the live surface is the `property_issues` CRUD below. Workflows above issue intake (assignment to a contractor, estimates, approvals) are modeled in the DB (migration 079) but not yet exposed via routes.

### Endpoints (`/api/v1/landlord`)

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/issues` | Report an issue (status defaults to `new`) |
| `GET` | `/issues` | List issues (filter by property/status) |
| `GET` | `/issues/:issueId` | Issue detail |
| `PATCH` | `/issues/:issueId` | Update status/priority/assignment/description |

### Status lifecycle

`new → acknowledged → under_assessment → awaiting_approval → approved → assigned → in_progress → awaiting_parts_access → resolved → closed` (plus `rejected`, `cancelled`). Status history is written by a DB trigger (migration 079). The dashboard counts "pending" as statuses `new, acknowledged, under_assessment, approved, assigned, in_progress`.

### Tables (migration `079_create_maintenance_tables.sql`)

`property_issues`, `maintenance_requests`, `maintenance_assignments`, `maintenance_estimates`, `maintenance_approvals`, `maintenance_attachments`, `maintenance_status_history`.

## 3. Garbage Services

**Fully implemented + tested.** Three resource groups under `/api/v1/landlord`:

| Resource | Paths | Notes |
|----------|-------|-------|
| Providers | `POST/GET/GET:id/PATCH:id/DELETE:id /garbage-providers` | Provider directory |
| Assignments | `POST/GET/GET:id/PATCH:id/DELETE:id /garbage-assignments` | Link providers to properties/units |
| Collection requests | `POST/GET/GET:id/PATCH:id/DELETE:id /garbage-collection-requests` | Status `pending → assigned → in_progress → completed/cancelled` |

Tables (migrations `071`, `072`): `garbage_providers`, `garbage_provider_assignments`, `garbage_collection_requests`, `unit_occupancy_history`. Seed migrations `073`/`074` wire listing + landlord garbage permissions.

## 4. Financial Reporting

### Dashboard endpoints (`/api/v1/landlord`)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/dashboard` | Core counts (properties, listings, units, tenancies, site visits, garbage) |
| `GET` | `/dashboard/extended` | Adds occupancy, enquiries, upcoming tenancy expiries, pending maintenance/garbage, and computed rent figures |

### Financial aggregates

`getExtendedDashboardStats` (landlord.repository.ts) computes, from invoices that carry at least one `rent` charge and are not `draft/cancelled/void`:

- `expectedRent` = Σ `total_amount`
- `collectedRent` = Σ `amount_paid`
- `outstandingRent` = Σ `amount_outstanding`
- `upcomingExpiries` = active tenancies with `end_date` within the next 30 days
- `pendingGarbageRequests` = collection requests in `pending/assigned/in_progress`

These were previously hardcoded to `0`; they are now derived from the financial tables (migration `078`).

### Financial CRUD (migration `078_create_financial_tables.sql`)

| Method | Path | Description |
|--------|------|-------------|
| `POST/GET` | `/invoices` | Create/list invoices |
| `GET` | `/invoices/:invoiceId` | Invoice detail |
| `POST` | `/payments` | Record a payment (updates invoice paid/outstanding) |
| `GET` | `/rent-ledger` | Rent ledger entries |

Tables: `invoices`, `invoice_items` (charge types incl. `rent`, `garbage_charge`, `maintenance_charge`, `utility_charge`), `payment_transactions` (idempotency-keyed), `payment_allocations`, `rent_ledger_entries`, `tenant_deposits`, `deposit_transactions`, `property_expenses`, `expense_categories`.

## 5. Other Property Services (Laundry / Movers)

Provider **discovery** by category exists (`modules/location/provider-discovery.*` with categories `laundry_service_provider`, `moving_service_provider`). There are **no dedicated laundry/mover backend modules or Flutter screens** — the Flutter `laundries`/`movers`/`garbage` feature directories are `.gitkeep` stubs and dashboard tiles show "coming soon".

## 6. Flutter Frontend

- Landlord dashboard (`landlord_dashboard_page.dart`) shows occupancy + counts via `dashboardStatsProvider`.
- Maintenance, garbage, laundry, and mover management UIs are **not implemented** in Flutter yet (no API-wired screens; service tiles are stubs).
- These landlord services are currently backend-only surfaces.

## 7. Testing

- `landlord.test.ts` — Garbage Management API, Dashboard API, Extended Dashboard API (including computed financial aggregates), Maintenance API.
- Financial aggregates are verified by seeding an invoice + rent item and asserting expected/collected/outstanding plus pending garbage counts.

## 8. OpenAPI

Maintenance (`/issues`), garbage (`/garbage-providers`, `/garbage-collection-requests`), and dashboard (`/dashboard`, `/dashboard/extended`) paths + schemas (`MaintenanceIssue`, `GarbageProvider`, `GarbageCollectionRequest`, `DashboardStats`, `ExtendedDashboardStats`) are documented in `server/openapi.yaml`.

## 9. Known Gaps

- `maintenance_requests` workflow routes not registered (issue intake only).
- No recurring rent invoice generation or automated payment reconciliation worker.
- Flutter screens for maintenance/garbage/laundry/movers not implemented (backend-first).
- No dedicated financial report endpoint (only dashboard aggregates).