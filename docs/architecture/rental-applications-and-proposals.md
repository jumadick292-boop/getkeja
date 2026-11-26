# Rental Applications and Proposals

End-to-end workflow for a house seeker applying for a rental opportunity,
landlord/manager review, versioned rental proposals and negotiation, and the
idempotent handoff to tenant onboarding.

## Existing infrastructure reused

- **Tables**: `rental_applications` + `rental_application_history` (migration
  048); `rental_proposals` + `rental_proposal_versions` +
  `rental_proposal_status_history` (077); `tenancies` (044); `tenants` (070);
  `units`, `properties`, `property_listings`, `property_ownerships`,
  `property_assignments`.
- **Messaging & notifications**: `NotificationService.createOutboxEvent`
  (transactional, idempotent by key) drained by the pg-boss outbox worker.
- **Private document storage**: `putPrivateDocument` / `signedPrivateDocumentUrl`
  (S3 with AES256 + short-lived signed URLs).
- **Authorization**: `canAccessProperty`, ownership + assignment checks. New
  scope helper `getManagerScope` (applicant / owner / approval-class assignment).
- **Tenancy/tenant creation**: column lists mirrored from
  `auth.repository.createTenancy` and `landlord.repository.createTenant`.

## Migrations

- **093_extend_rental_application_lifecycle**: extends the `application_status`
  enum with `draft, information_requested, resubmitted, shortlisted,
  proposal_sent, negotiation, cancelled`; adds `rental_applications.updated_by`;
  adds `rental_application_notes` (private internal + applicant-visible notes)
  and `rental_application_documents` (secure document metadata); adds an
  `AFTER UPDATE` trigger writing a history row on every status change.
- **094_rental_application_initial_history**: `AFTER INSERT` trigger writing the
  initial history row (submitted/draft) with the applicant as actor.

## Application lifecycle

The authoritative state machine lives in
`server/src/modules/rental-applications/rental-application.lifecycle.ts`. The
database trigger records history; the service enforces legal transitions and
actor authorization.

States: `draft → submitted → under_review → information_requested →
resubmitted → shortlisted → proposal_sent → negotiation → approved | rejected |
withdrawn | expired | cancelled` (legacy `pending_documents`, `pending_payment`
retained).

Actor kinds: `applicant`, `manager`, `system`. Each action declares the source
statuses and allowed actors. Examples:

| Action | From | Actor | To |
| --- | --- | --- | --- |
| submit | draft | applicant | submitted |
| start_review | submitted, resubmitted, pending_documents | manager | under_review |
| request_information | submitted, under_review, resubmitted | manager | information_requested |
| resubmit | information_requested, pending_documents | applicant | resubmitted |
| shortlist | submitted, under_review, resubmitted | manager | shortlisted |
| send_proposal | shortlisted, under_review, proposal_sent, negotiation | manager | proposal_sent |
| approve | under_review, shortlisted, negotiation, proposal_sent, pending_payment | manager | approved (+ onboarding) |
| reject | most active states | manager | rejected |
| withdraw | most non-terminal states | applicant | withdrawn |

`rental_application_history` is written by DB triggers (migration 093/094), never
by hand, so every transition is auditable with actor + timestamp.

## Proposal versioning

Proposals live in `rental_proposals` with append-only `rental_proposal_versions`
and `rental_proposal_status_history`. A counter-offer creates a new version row;
terms already received by the applicant are never overwritten. Overdue pending
proposals (`sent`, `under_review`, `changes_requested` past `expires_at`) are
lazily expired by `expireOverdueProposals()` on each seeker proposal list/get.

## Tenant onboarding handoff

`rental-onboarding.service.initiateOnboarding(applicationId, actorId)` is the
only path that creates a tenant. It is idempotent and concurrency-safe:

1. Locks the application row (`FOR UPDATE`); if `tenancy_id` is already set it
   returns the existing tenancy (safe retry).
2. Requires `status = 'approved'`, a non-null `unit_id`, and a unit that is not
   occupied and has no competing approved application and no active tenancy.
3. Creates the tenancy (`active`) and tenant (`active`) atomically, links
   `rental_applications.tenancy_id`, and flips the unit to `occupied`.

Nothing creates a tenant before approval: submitting an application, an
enquiry, a site visit, or accepting a proposal never creates a tenant or tenancy.

## Authorization and privacy

- Applicants access only their own applications (`userId` from the token, never
  the client body).
- Managers are active owners or holders of a `property_manager`/`letting_agent`
  assignment. Caretakers, maintenance and security assignments are excluded from
  review/approval. Organization membership alone grants no application access.
- Internal notes (`is_internal = true`) are never returned to applicants; the
  applicant detail view filters to `is_internal = false`.
- Information-request messages are stored as applicant-visible notes
  (`is_internal = false`).
- Private documents use the existing private S3 storage with short-lived signed
  URLs; download is authorized to the applicant or a manager.

## Concurrency safeguards

- Duplicate active application prevention: transaction-scoped advisory lock on
  applicant+property+unit, then an active-status check.
- Competing approvals: approval locks the unit row (`FOR UPDATE`) and rejects if
  another application is already approved for the unit or the unit is occupied.
- Onboarding idempotency: application row lock + existing `tenancy_id` check;
  retries return the same tenancy without duplicating rows.

## API endpoints (`/api/v1/rental-applications`)

Applicant: `POST /applications/draft`, `POST /applications`,
`POST /applications/:id/submit`, `POST /applications/:id/resubmit`,
`POST /applications/:id/withdraw`, `GET /applications/:id`.

Manager: `GET /applications` (inbox, filterable), `GET /applications/:id`
(detail + history + notes + documents),
`POST /applications/:id/transition`, `POST /applications/:id/approve`,
`POST /applications/:id/onboard`, `POST /applications/:id/notes`.

Documents (shared): `POST /applications/:id/documents` (multipart upload),
`GET /applications/:id/documents`, `GET /documents/:documentId` (signed URL).

All routes use Zod validation, central error handling, transactions and
resource-scoped authorization.