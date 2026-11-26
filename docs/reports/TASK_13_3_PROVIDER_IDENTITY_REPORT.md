# Task 13.3 — Provider Identity, Organizations, and Staff

## Scope

Provider identity, organizations, and staff onboarding for the get.keja
platform: backend endpoints, Flutter screens, tests, and docs, preserving RBAC,
tenant isolation, and verification rules.

## What was built

### Backend

- **Reused** existing profile and organization modules; added provider-scoped
  delegating endpoints under `/api/v1/provider/*` (profiles, organizations,
  staff, invitations).
- **`auth.repository.ts`**: `findOrganisationInvitationById`,
  `setOrganisationActive`, `declineOrganisationInvitation`,
  `addActiveOrganisationMember`; fixed `createAuthorizationAuditEvent` columns;
  replaced `invited_at` selects with `created_at as "invitedAt"`.
- **`organisation.service.ts`**: fixed `revokeInvitation` to use the invitation
  id; added `declineInvitation` and `deactivateOrganisation`; `createInvitation`
  returns the raw token; added `mapOrgRoleToRoleId`; creator added as active
  member; `acceptInvitation` inserts active membership; role assignments include
  `resourceType`/`resourceId`.
- **`provider.authorization.ts`**: active-organization filtering; garbage query
  matches `specialized_profile_id` / `organisation_id` / `created_by`.
- **`provider.controller.ts` / `provider.routes.ts`**: profile/org/staff/
  invitation endpoints.
- **`profile.controller.ts`**: `listServiceAreas` reads `profileId` from query.
- **Migrations**:
  - `105_provider_profile_uniqueness.sql` — guarded partial unique indexes.
  - `106_provider_identity_convergence.sql` — `organisations.is_active`,
    `garbage_providers.specialized_profile_id` + `DISTINCT ON` backfill.

### Flutter

- Datasource + repository: `listProfiles`, `createProfile`,
  `listOrganizations`, `createOrganization`, `listStaff`, `inviteStaff`.
- `ProviderOnboardingPage` — individual/organization toggle, category,
  API-backed submit with loading/error/success.
- `ProviderOrganizationsPage` — list organizations + invite-staff dialog.
- `providerOrganizationsProvider` state.
- Routes: `/provider/onboarding`, `/provider/organizations`.

### Docs / API

- `docs/architecture/provider-profiles-organizations-and-staff.md`.
- OpenAPI: provider profiles/organizations/staff/invitations paths.

## Verification

- Backend typecheck: clean.
- Backend tests: **562 passed** (38 files), including
  `provider-identity.test.ts` (11).
- Flutter analyze: 0 errors.
- Flutter tests: **198 passed**, including `provider_onboarding_test.dart` (2).
- Migrations: 105/106 applied, re-run is a no-op (idempotent); partial unique
  indexes `uq_specialized_profiles_individual` / `uq_specialized_profiles_org`,
  `organisations.is_active`, and `garbage_providers.specialized_profile_id`
  confirmed present.
- OpenAPI parses (149 paths).

## Notes / follow-ups

- Onboarding is a single API-backed form (foundation); full multi-step wizard
  and document upload are deferred.
- Organization role management UI beyond invite/remove is deferred.