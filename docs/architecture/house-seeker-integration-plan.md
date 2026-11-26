# House Seeker — Integration Plan & Module Dependencies

**Scope:** Task 1 foundation only. The House Seeker feature already exists end-to-end
(backend `modules/house-seeker`, mobile `features/house_seeker`). No new feature
endpoints or UI are added in this task.

## 1. Integration boundaries

The House Seeker module consumes the shared listing system; it does **not** create
separate property, unit, or listing tables.

| Boundary | Source of truth | House Seeker usage |
|---|---|---|
| Published property listings | `modules/listings` + tables `properties`, `property_listings`, `units` | Read-only discovery: search, featured, recently published, map results, filter facets, listing detail. Queries filter `pl.status = 'published'`. |
| Available units | `units` table | Joined via `property_listings.unit_id` for bedroom/bathroom/unit number/rent; no separate unit management. |
| Property locations | `properties` table (city, county, address, latitude, longitude) | Search/filter by city/county/neighbourhood; map viewport queries; lat/long on listing cards. |
| Saved homes | `saved_listings` (migration 083) | User-scoped favourites; references `property_listings.id` (ON DELETE CASCADE); unique on `(user_id, listing_id)`. |
| Saved searches | `saved_searches` (migration 083) | Criteria stored as JSONB; alert-ready; user-scoped. |
| Enquiries | `property_enquiries` (+ status history, notes, assignments, migration 075) | House seeker creates enquiries against published properties/listings; landlord module manages the same enquiries server-side. Shared tables, separate route prefixes (`/api/v1/house-seeker/enquiries` vs landlord routes). |
| Conversations | `conversations`, `conversation_participants`, `messages`, `message_read_states`, `message_attachments` (migration 076) | Seeker starts conversations with a landlord participant; participant-scoped reads (403 for non-participants). |
| Site visits | `site_visits` (+ history, migration 047) | Seeker requests future-dated visits on published listings; cancels/reschedules own visits; landlord sees requests for properties they own. |
| Rental proposals | `rental_proposals` + `rental_proposal_versions` + status history (migration 077) | Seeker responds (accept/decline/request_changes/counter); counter creates a new version row. Landlord module sends proposals. |
| Rental applications | `rental_applications` (+ history, migration 048) | Seeker submits against published listing/property; withdraws own applications while in withdrawable states. |
| Tenant onboarding | `tenancies`, `tenancy_participants`, `tenants` (migrations 044/045/070) | Out of scope for Task 1. Integration point: accepted proposal/application → onboarding flow (Phase 2+). No tenancy writes from House Seeker yet. |

## 2. Published-and-eligible listing rule

House Seeker discovery queries (`searchListings`, `getMapListings`, `getPublicListingById`, `saveListing`) all require `property_listings.status = 'published'`. Enquiries, site visits, and applications validate that the referenced listing (or at least one listing on the property) is published, otherwise `409`. Draft/suspended listings never appear in discovery. This satisfies "House Seekers must consume published and eligible listings from the shared listing system."

## 3. Module dependency graph (backend)

```
modules/house-seeker
  ├── modules/auth            — requireAuth, AuthUser, sessions,
  │                              createSiteVisit/createRentalApplication helpers,
  │                              findSiteVisitById/findSiteVisitsByUser,
  │                              findRentalApplication*/NotificationService
  ├── modules/landlord        — createEnquiry, findRentalProposalById,
  │                              setRentalProposalStatus
  ├── shared/errors           — HttpError hierarchy
  ├── shared/logger
  ├── db/pool                 — shared pg Pool
  ├── db/tx                   — shared transaction helper (NEW in Task 1)
  ├── db/redis                — shared Redis client
  └── config/env              — validated environment
```

Dependency direction: feature modules depend only on `shared/`, `db/`, `config/`, and upstream domain modules (`auth`, `landlord`). No module depends on `house-seeker`. No circular dependencies.

Depended-upon tables owned by other modules (read-only or via shared repository helpers): `users`, `user_profiles`, `user_roles`, `properties`, `property_ownerships`, `units`, `property_listings`, `conversations`, `messages`, `site_visits`, `rental_applications`, `rental_proposals`, `property_enquiries`, `notification_outbox`.

House-seeker-owned tables (migration 083): `house_seeker_preferences`, `saved_listings`, `saved_searches`, `listing_reports`.

## 4. Mobile integration points

- Single API client: `core/api/api_client.dart` (`apiClientProvider`, Dio with Bearer token + 401 refresh).
- House Seeker datasource: `features/house_seeker/data/datasources/house_seeker_remote_datasource.dart` → `${ApiConfig.baseUrl}/api/v1/house-seeker`.
- Repository interface + impl: `domain/repositories/house_seeker_repository.dart`, `data/repositories/house_seeker_repository_impl.dart`.
- Riverpod providers in `presentation/state/house_seeker_state.dart`; pages call providers only — no Dio in widgets.
- Routes registered in `app/router/app_router.dart` under `/house-seeker/*`, auth-guarded.

## 5. API conventions

- Base paths: `/api/v1/<feature>` canonical; `/api/<feature>` kept for auth/profile compatibility.
- All House Seeker routes require `requireAuth` (Bearer `Authorization` or `x-access-token`).
- Validation: `zod` schemas at route boundary; errors return `{ success: false, message, code }`.
- Full reference: `server/API.md`, `server/openapi.yaml`.

## 6. Migration conventions

- Files: `server/src/db/migrations/NNN_descriptive_name.sql` (81 applied, `083_create_house_seeker_tables` is the latest).
- Runner: `db/migrate.ts` — checksum-verified, each migration in its own transaction, tracked in `_migrations` table (`id`, `name`, `checksum`, `applied_at`).
- Commands: `npm run migrate` (up), `npm run migrate:status`, `npm run migrate:create <name>`.
- No drift allowed between applied checksums and files.
- New House Seeker tables in Phase 2+ must add a new numbered migration only; never edit applied migrations.
