# Rental Proposals & Rental Applications — Implementation

**Repository:** `get-keja-repo`
**Backend:** `server/` (Node.js/Express/PostgreSQL)
**Flutter app:** `Mobile/` (Flutter 3.50.0, Riverpod 3, Dio, GoRouter)
**Feature:** Seeker responds to landlord rental proposals (accept/decline/request_changes/counter) and submits/tracks rental applications

## 1. Overview

Landlords send rental proposals to prospective renters (House Seekers). Seekers review, accept, decline, request changes, or counter with new terms. In parallel, seekers can submit rental applications directly against a published listing and track their status, withdrawing while still in a withdrawable state. Both flows are backed by real tables, status history, and versioning.

## 2. User Workflows

### Respond to a Proposal (House Seeker)

1. Seeker views proposals at `/house-seeker/proposals`.
2. `GET /api/v1/house-seeker/proposals` lists proposals where the seeker is the prospective renter.
3. Seeker opens a proposal and chooses an action:
   - **Accept** → `POST /api/v1/house-seeker/proposals/:proposalId/respond` `{ action: 'accept' }` → status `accepted`.
   - **Decline** → same endpoint `{ action: 'decline' }` → status `declined`.
   - **Request changes** → `{ action: 'request_changes' }` → status `changes_requested`.
   - **Counter** → `{ action: 'counter', counter: { rentAmount, depositAmount } }` → status `under_review` and a new `rental_proposal_versions` row is created.
4. Actionable only when status is `sent`, `under_review`, or `changes_requested`. IDOR-guarded: a seeker can only act on their own proposals (403 otherwise).

### Send a Proposal (Landlord)

1. Landlord creates a proposal via `POST /api/v1/landlord/rental-proposals`.
2. Proposal starts in `draft`; landlord sends it (`action: 'send'`) → `sent`.
3. Landlord can `request_changes`, `accept`, `decline`, `withdraw`, `confirm` via `POST /api/v1/landlord/rental-proposals/:proposalId/action`.

### Submit & Track an Application (House Seeker)

1. Seeker submits an application against a published listing: `POST /api/v1/house-seeker/applications`.
2. Seeker lists/tracks applications at `/house-seeker/applications`.
3. Seeker can withdraw while status is not in `approved/rejected/withdrawn/expired`: `POST /api/v1/house-seeker/applications/:applicationId/withdraw`.

## 3. Database Schema

### Rental proposals — migration `077_create_rental_proposal_tables.sql`

| Table | Purpose |
|-------|---------|
| `rental_proposals` | Proposal header: property, unit, prospective renter, landlord, type, status, proposed rent/deposit/start/end/due day, expires_at |
| `rental_proposal_versions` | Versioned counter offers (each counter creates a new row) |
| `rental_proposal_status_history` | Append-only status audit |

Enums: `rental_proposal_status` (draft/sent/under_review/changes_requested/accepted/declined/withdrawn/confirmed/expired), `rental_proposal_type`.

### Rental applications — migration `048_create_rental_applications_table.sql`

| Table | Purpose |
|-------|---------|
| `rental_applications` | Application: property/unit/applicant, proposed rent, preferred dates, employer/income, status, review notes, rejection reason |
| `rental_application_history` | Append-only status audit |

Enum `application_status`: submitted/under_review/approved/rejected/withdrawn/pending_documents/pending_payment/expired.

## 4. Backend Architecture

### House Seeker (responder/applicant)

| Layer | Location |
|-------|----------|
| Routes | `house-seeker.routes.ts:143-153` |
| Controller | `house-seeker.controller.ts:477-522` (`submitApplication`, `listApplications`, `getApplication`, `withdrawApplication`, `listProposals`, `getProposal`, `respondToProposal`) |
| Repository | `house-seeker.repository.ts:1175-1357` (`createSeekerApplication`, `listMyApplications`, `getMyApplication`, `withdrawMyApplication`, `listMyProposals`, `getMyProposal`, `respondToMyProposal`) |

### Landlord (sender)

| Layer | Location |
|-------|----------|
| Routes | `landlord.routes.ts:371-375` |
| Controller | `landlord.controller.ts:1334-1449` (`createRentalProposal`, `getRentalProposal`, `updateRentalProposal`, `listRentalProposals`, `actionRentalProposal`) |
| Repository | `landlord.repository.ts:2434-2717` (proposal CRUD + `setRentalProposalStatus` + `createRentalProposalVersion`) |

### Shared rental_applications (auth/resource module)

| Layer | Location |
|-------|----------|
| Routes | `auth/resource.routes.ts:128-132` |
| Controller | `auth/resource.controller.ts:540-605` |
| Repository | `auth/auth.repository.ts:3874-4042` |
| Authorization | `auth/authorization.service.ts:850` (`canAccessRentalApplication`), `authorization.middleware.ts:613` |

## 5. API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/house-seeker/proposals` | List seeker's proposals |
| `GET` | `/api/v1/house-seeker/proposals/:proposalId` | Proposal detail |
| `POST` | `/api/v1/house-seeker/proposals/:proposalId/respond` | Accept/decline/request_changes/counter |
| `POST` | `/api/v1/house-seeker/applications` | Submit application |
| `GET` | `/api/v1/house-seeker/applications` | List seeker's applications |
| `GET` | `/api/v1/house-seeker/applications/:applicationId` | Application detail |
| `POST` | `/api/v1/house-seeker/applications/:applicationId/withdraw` | Withdraw application |
| `POST` | `/api/v1/landlord/rental-proposals` | Create proposal |
| `GET` | `/api/v1/landlord/rental-proposals` | List landlord proposals |
| `GET` | `/api/v1/landlord/rental-proposals/:proposalId` | Proposal detail |
| `PATCH` | `/api/v1/landlord/rental-proposals/:proposalId` | Update proposal |
| `POST` | `/api/v1/landlord/rental-proposals/:proposalId/action` | Send/request_changes/accept/decline/withdraw/confirm |

## 6. Flutter Frontend

| File | Route | Description |
|------|-------|-------------|
| `house_seeker_proposals_page.dart` | `/house-seeker-proposals` | List, accept/decline dialogs, counter-offer dialog (rent/deposit) |
| `house_seeker_applications_page.dart` | `/house-seeker-applications` | List, withdraw dialog |

Providers: `houseSeekerProposalsProvider`, `houseSeekerApplicationsProvider` (both `FutureProvider`). Models: `RentalProposalModel` (`canRespond` when status in sent/under_review/changes_requested), `RentalApplicationModel` (`canWithdraw` unless approved/rejected/withdrawn/expired).

Note: landlord-side proposal creation UI is not yet implemented in Flutter; proposals are created server-side via the landlord API.

## 7. Testing

### Backend
- `house-seeker.test.ts` — applications (submit/list/withdraw, IDOR) + proposals (list/accept/IDOR).
- `landlord.test.ts` — proposal create/list/send/accept.

### Flutter
- `house_seeker_proposals_test.dart` — 6 tests (loading, empty, actionable terms+buttons, read-only, accept flow, error notice).
- `house_seeker_applications_test.dart` — 6 tests (loading, empty, withdrawable+button, read-only, withdraw flow, error notice).

## 8. OpenAPI

Proposal and application paths + schemas (`RentalProposal`, `RentalApplication`, `RespondToProposalRequest`, list responses) are documented in `server/openapi.yaml`.

## 9. Verification

- Backend: `npx tsc --noEmit` clean, `npx vitest run` green.
- Flutter: `flutter analyze` 0 errors, `flutter test` green.
- OpenAPI: parses, 0 unresolved refs.