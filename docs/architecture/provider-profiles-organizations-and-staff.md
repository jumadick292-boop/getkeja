# Provider Profiles, Organizations, and Staff

Task 13.3 builds provider identity on top of the existing GetKeja identity and
RBAC primitives. It does not duplicate the profile or organization modules; it
composes them and exposes provider-scoped, tenant-safe endpoints.

## Reused primitives

- **Profile** (`/api/v1/profile/*`): specialized provider profiles live in
  `specialized_profiles` with a `profile_category` of
  `moving_service_provider`, `garbage_collection_provider`, or
  `laundry_service_provider`.
- **Organization** (`/api/v1/auth/organisations/*`): organizations, membership,
  invitations, and role assignments.
- **RBAC**: `role_assignments` (global / organization / resource scope) and
  `authorization_audit_events`.

## Duplicate-profile prevention

`profile.repository.createSpecializedProfile` rejects a second profile for the
same `(user_id, profile_category, organisation_id)` with `ConflictError` (409).
Migration `105_provider_profile_uniqueness.sql` enforces this at the database
level with two partial unique indexes:

- `uq_specialized_profiles_individual` on `(user_id, profile_category)` where
  `organisation_id IS NULL`.
- `uq_specialized_profiles_org` on
  `(user_id, profile_category, organisation_id)` where
  `organisation_id IS NOT NULL`.

The migration is guarded (only creates indexes when absent) and idempotent.

## Identity convergence

Migration `106_provider_identity_convergence.sql` is non-destructive:

- Adds `organisations.is_active` (default `true`) so deactivation is soft and
  authorization can filter inactive organizations.
- Adds `garbage_providers.specialized_profile_id` and backfills it with
  `DISTINCT ON` from the owning user's specialized profile, so a garbage
  provider row converges onto its canonical profile without dropping data.

## Provider-scoped endpoints

All under `/api/v1/provider/*`, authenticated, and scoped to the caller's
active organization / approved profile:

| Method | Path | Purpose |
| ------ | ---- | ------- |
| GET | `/provider/profiles` | List the caller's specialized profiles |
| POST | `/provider/profile` | Create an individual profile (409 on duplicate) |
| GET | `/provider/organizations` | Organizations the caller belongs to |
| POST | `/provider/organizations` | Create an organization (creator = owner) |
| GET | `/provider/organizations/{orgId}/staff` | List members |
| DELETE | `/provider/organizations/{orgId}/staff/{memberId}` | Remove member (owner/admin) |
| POST | `/provider/organizations/{orgId}/invitations` | Invite staff by email |

## Authorization and tenant isolation

- `provider.authorization.ts` filters organizations to active memberships and
  scopes garbage-provider queries to `specialized_profile_id` /
  `organisation_id` / `created_by`.
- Organization creation adds the creator as an active `owner` member and a
  global `organization_owner` role assignment; invitations and role changes
  create/refresh role assignments via `mapOrgRoleToRoleId`.
- Last-owner protection and authorization-cache invalidation are preserved from
  the base organization service.
- Staff removal and invitation require owner/admin; non-owners receive 403.

## Registration roles

Public registration accepts only:
`house_seeker, tenant, landlord, caretaker, property_manager, letting_agent,
moving_company, individual_mover, garbage_provider, laundry_provider,
service_provider`. `organization_member` is not a valid public registration
role.