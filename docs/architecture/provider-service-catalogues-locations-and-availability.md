# Provider Service Catalogues, Locations and Availability (Task 13.4)

This document describes the provider service-configuration foundation for moving,
garbage-collection and laundry businesses. It builds on Tasks 13.1–13.3 and
reuses the existing identity, organization/RBAC, location and service-request
infrastructure. It does **not** implement customer quotation, booking or
job-processing workflows (later tasks).

## 1. Audit outcome (what is authoritative)

- `specialized_profiles` (one identity; `profile_category` ∈ moving/garbage/laundry;
  `verification_status`) — authoritative provider profile.
- `provider_service_areas` (county/town/neighbourhood + lat/lng + `radius_km`) —
  authoritative coverage; reused and extended with a nullable `offering_id`.
- `saved_locations` (types incl. `business_office`/`provider_operating`) — reused
  and extended for business ownership/visibility (no duplicate location table).
- `organisations` + `organisation_members` + `role_assignments` — authoritative
  org/permission model; reused for catalogue authorization.
- Reference data (categories/capabilities) did not exist → introduced as
  platform-admin-managed tables (providers cannot create global categories).

## 2. Shared catalogue design

- **Platform reference data**: `service_categories` and `service_capabilities`
  (per `service_domain`), seeded by migration, `is_active`, admin-managed only.
- **Provider offering**: `provider_service_offerings` — one row per
  `(specialized_profile_id, category_id)` (unique), with `domain`, `title`,
  `description`, `service_type`, `status`, `config` (JSONB, domain-specific), and
  an optional temporary-unavailability window.
- **Capabilities**: `provider_service_offering_capabilities` (offering ×
  capability, `enabled`, `detail`) — normalized; only domain-valid capabilities
  accepted.
- **Pricing**: `provider_service_pricing` (1:1 with offering) — `pricing_model`
  (fixed/starting/per_item/per_unit/per_km/hourly/weight/volume/custom_quote),
  `currency` (default `KES`), `base_amount`/`minimum_charge` as `NUMERIC(12,2)`
  (never float), `unit_label`, `quotation_required`, `is_indicative`,
  `price_notes`.
- **Coverage**: `provider_service_areas.offering_id` (nullable) — profile-level
  (legacy) or offering/category-specific coverage.
- **Locations**: `saved_locations` extended with `is_public`, `visibility`,
  `organisation_id`, `is_primary`, `is_active` (+ partial unique primary indexes).
- **Operating hours**: `provider_operating_hours` (profile- or offering-scoped,
  multiple windows/day, `is_closed`, `time_zone` default `Africa/Nairobi`).
- **Exceptions**: `provider_availability_exceptions` (temporary closures /
  special days, unique per profile+offering+date).

### Lifecycle

`draft → active → paused/unavailable → archived`. Transitions are validated in
the service layer (`TRANSITIONS`). A `pause` with a start/end date sets
`unavailable`; without a window it sets `paused`. Only `active` (or an
`unavailable` offering whose temporary window has expired) is discoverable.

## 3. Service-specific configuration

- **Moving**: category (household/apartment/office/…), `config` holds property/
  move types, packing/loading/furniture/fragile/appliance options, coverage.
- **Garbage**: category (residential/commercial/estate/scheduled/one-time/bulk/
  recycling); capabilities express eligibility & collection methods; recurring
  generation is deferred.
- **Laundry**: category (washing/drying/ironing/dry-cleaning/folding/bedding/
  household/commercial/pickup-delivery); capabilities + turnaround in `config`.

Capabilities are validated against the offering's domain; irrelevant fields are
simply not shown by the client.

## 4. Pricing safety

- Exact decimals: `NUMERIC(12,2)` in DB; TS handles amounts as strings
  (`toFixed(2)`), never floating point.
- No price is invented: `base_amount` is nullable; `quotation_required` and
  `is_indicative` distinguish an indicative public starting price from a binding
  quotation.
- No invoices/payments/ledger are created here.

## 5. Locations & privacy

- Business/operating locations reuse `saved_locations` (no duplicate system).
- `personal_residential` locations can never be `public` (service rejects).
- Only `is_public = true` locations are intended for business discovery;
  customer pickup/delivery coordinates are never exposed by this module.
- Primary location enforced per organization and per individual (partial unique
  indexes); `set-primary` clears the previous primary transactionally.

## 6. Service-area matching & discovery

- Discovery (Haversine + textual fallback) and the provider inbox/dashboard
  eligibility now apply a **backward-compatible offering gate**: a profile with
  **no** offerings remains eligible (legacy providers keep working); a
  catalogue-managed profile is eligible only when it has an `active` offering in
  the domain (or an expired temporary closure). This ensures a provider only
  receives requests for services it actually offers, without breaking existing
  providers.
- Coverage can differ per offering (offering-scoped areas).

## 7. Operating hours & temporary availability

- Reusable weekly hours (multiple windows/day, closed days, `Africa/Nairobi`).
- Temporary closures via `provider_availability_exceptions` and the offering
  `unavailable` status with a start/end window.
- Expired closures never permanently disable a provider: the gate treats an
  expired `unavailable` offering as active, and a pg-boss cron worker
  (`provider-availability.worker.ts`, every 15 min) resets expired `unavailable`
  offerings back to `active`. No uncontrolled `setInterval` workers.

## 8. Provider authorization

Every operation resolves the provider context (`resolveProviderContext`) and
authorizes by **ownership/active membership**, never by id alone (IDOR-safe):

- Individual: only the user's own approved profiles.
- Organization: active membership + (`organization_owner`/`organization_admin`
  role or the relevant permission: `provider.catalogue.manage`,
  `provider.locations.manage`, `provider.service_areas.manage`,
  `provider.availability.manage`). Finance/operational staff do not
  automatically gain catalogue admin rights.
- Revoked membership / role changes remove access (respects Task 12.6 cache
  invalidation).

## 9. API catalogue (all under `/api/v1/provider`, Zod-validated)

- `GET /services/catalogue`, `GET /services/catalogue/:serviceType`
- `GET/POST /services`, `GET/PATCH /services/:serviceId`
- `POST /services/:serviceId/activate|pause|archive`
- `GET/PATCH /services/:serviceId/capabilities`
- `GET/PUT /services/:serviceId/pricing`
- `GET/POST /locations`, `PATCH/DELETE /locations/:locationId`,
  `POST /locations/:locationId/set-primary`
- `GET/POST /service-areas`, `PATCH/DELETE /service-areas/:areaId`
- `GET/PUT /availability`, `GET/POST /availability/exceptions`,
  `PATCH/DELETE /availability/exceptions/:exceptionId`

All responses use the `{ success, data }` envelope; OpenAPI coverage added.

## 10. Flutter

- Datasource/repository extended with catalogue, offerings, capabilities,
  pricing, locations, service areas, availability and exceptions.
- State: `providerServicesProvider`, `providerLocationsProvider`,
  `providerServiceAreasProvider`, `providerAvailabilityProvider`.
- Screens (API-backed, design system, EN/SW): `ProviderServicesPage` (overview +
  create), `ProviderLocationsPage` (list/add/primary/delete, public/private),
  `ProviderServiceAreasPage` (list/add/delete), `ProviderAvailabilityPage`
  (weekly hours + temporary closure).
- Routes: `/provider/services`, `/provider/locations`,
  `/provider/service-areas`, `/provider/availability`.
- No fake map pins or demo data.

## 11. Database changes

Migration `107_provider_service_catalogue.sql` (additive, idempotent):
enums `service_domain`/`provider_offering_status`/`pricing_model`; tables
`service_categories`, `service_capabilities`, `provider_service_offerings`,
`provider_service_offering_capabilities`, `provider_service_pricing`,
`provider_operating_hours`, `provider_availability_exceptions`; extends
`provider_service_areas` (`offering_id`) and `saved_locations`
(`is_public`/`visibility`/`organisation_id`/`is_primary`/`is_active`); seeds 26
categories + 19 capabilities + 4 permissions. No existing provider/location/
request records are dropped or destructively rewritten.

## 12. Known limitations / future integration

- Onboarding remains a single API-backed form (full wizard + document upload
  deferred).
- Fine-grained request-category matching is domain-level + active-offering gate;
  exact per-category request matching is a later refinement.
- Customer quotation, booking slots, recurring collection generation, laundry
  order processing, payments/payouts and live tracking are out of scope.
- The pricing model is a configuration foundation; binding quotations are a
  later task.