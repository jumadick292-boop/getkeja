# Reviews & Complaints

Task 13.16. Verified provider reviews and a complaint lifecycle shared across
customer, provider, and administrator roles.

## Reviews
- A review is **eligible** only when its underlying job is completed and
  customer-confirmed (`isReviewEligible` in
  `server/src/shared/operationalResources.ts`).
- One review per job, enforced by a unique index on
  `(resource_domain, resource_id)`.
- Reviews are polymorphic via `resource_domain` + `resource_id`, so the same
  table serves all seven job domains.
- Only **published** reviews contribute to a provider's average rating.
- Providers may post one response per review (`provider_review_responses`).
- Reporting/moderation uses `provider_review_reports` and an append-only
  `provider_review_status_history`.

### Tables (migration 129_provider_reviews)
`provider_reviews`, `provider_review_responses`, `provider_review_reports`,
`provider_review_status_history`; enum `review_status`.

### Permissions
`provider.reviews.view`, `provider.reviews.respond`, `review.moderate`.

## Complaints
- Complaints **never** change a job's completion status and never move money.
- Lifecycle states: `open`, `under_review`, `acknowledged`,
  `resolution_proposed`, `resolved`, `closed`, `rejected`.
- Only `closed` is terminal. `resolved → closed` and `resolved → under_review`
  are permitted. Illegal or terminal transitions throw `ConflictError` (HTTP
  409). Lifecycle rules live in `complaints/lifecycle.ts`.
- Messages (`complaint_messages`) are visible to customer, provider, and admin.
- Corrective actions (`complaint_corrective_actions`) are recorded by
  provider/admin.
- Internal notes (`complaint_internal_notes`) are **admin-only** and are never
  returned to customers or providers.
- `complaint_status_history` is append-only.

### Tables (migration 130_provider_complaints)
`complaint_reasons` (8 seeded), `complaints`, `complaint_messages`,
`complaint_corrective_actions`, `complaint_internal_notes`,
`complaint_status_history`; enum `complaint_status`.

### Permissions
`provider.complaints.view`, `provider.complaints.respond`, `complaint.manage`.

## Endpoints
- `/api/v1/reviews` — submit (customer), list mine, list provider, respond,
  rating lookup, moderation.
- `/api/v1/complaints` — submit (customer), list mine/provider/admin, detail,
  post message, record corrective action, change status, internal notes.

## Flutter surface
Pages under `Mobile/lib/features/provider_platform/presentation/pages/`:
- `provider_reviews_page.dart`, `customer_reviews_page.dart`.
- `customer_complaints_page.dart`, `provider_complaints_page.dart`,
  `admin_complaints_page.dart`, `complaint_detail_page.dart`.

Routes: `/provider/reviews`, `/reviews/mine`, `/provider/complaints`,
`/complaints/mine`, `/complaints/admin`, `/complaints/:complaintId`.

## Migrations
Both migrations are idempotent (`npm run migrate up`); re-running reports
`No pending migrations`. Permissions use `ON CONFLICT DO NOTHING` because the
permissions table has UNIQUE constraints on both `id` and `name`.