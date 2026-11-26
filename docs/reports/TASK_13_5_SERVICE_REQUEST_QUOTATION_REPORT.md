# Task 13.5 — Service Request & Quotation Marketplace Report

## Scope

Unified service-request + quotation marketplace covering 18 categories across
the home-services domains, reusing the Task 13.4 provider catalogue, identity,
locations, service areas, org/RBAC, outbox and the Flutter design system. No
payments, payouts, tracking or reviews. Catalogue prices remain indicative only;
the accepted quotation is the binding commercial artefact.

## Pre-implementation audit

See `docs/architecture/service-marketplace-audit.md`. Decision: add ONE reusable
request engine (`service_requests` + history + quotations + items + attachments)
rather than duplicating the legacy per-domain request tables. Legacy
moving/laundry/garbage tenant endpoints remain untouched (regression preserved).

## What was built

### Database (migrations 108–110, additive + idempotent)
- **108** extends the `service_domain` enum with 13 new domains (cleaning,
  plumbing, electrical, hvac, pest_control, landscaping, carpentry, painting,
  roofing, flooring, tiling, appliances, general). Enum-only; values are seeded
  in 109 so they are never used in the same transaction (PostgreSQL rule).
- **109** seeds 18 marketplace categories + per-domain capabilities, and creates
  the unified engine:
  - `service_requests` (category-scoped, Zod-validated `details` JSONB,
    lifecycle status, service location, contact, accepted/assigned linkage).
  - `service_request_history` (append-only; updated by trigger on status change).
  - `service_quotations` (append-only revisions; `version_number`, partial unique
    index = one live quotation per provider per request).
  - `service_quotation_items`, `service_request_attachments` (loose link to the
    existing private-document subsystem).
  - Enums `service_request_status`, `service_quotation_status`.
  - Permissions `provider.marketplace.respond` / `provider.marketplace.manage`.
- **110** adds the terminal `superseded` quotation status so a revision frees the
  live slot before its replacement is inserted (keeps the unique index intact).

### Backend (`server/src/modules/marketplace/`)
- `marketplace.types.ts`, `marketplace.schemas.ts` (strict Zod; `details`
  `.strict()` rejects arbitrary keys), `marketplace.lifecycle.ts` (single
  transition matrix + quotable guard).
- `marketplace.repository.ts` — scoped SQL; writes accept the caller's
  `PoolClient` so business change + history + outbox share one transaction.
- `marketplace.service.ts`:
  - Customer: create / list / detail / cancel (cancels withdraw live quotations).
  - Provider: inbox (offering gate + service-area match), detail (adds
    `eligibleProfileIds`), submit/revise quotation, withdraw, advance job.
  - **Atomic acceptance**: `SELECT … FOR UPDATE` on the request + target
    quotation, version/expiry checks, accept winner, decline other live
    quotations, flip request to `accepted`, set `assigned_provider_id`, enqueue
    a CRITICAL outbox event — all in one transaction.
- `marketplace.controller.ts`, `marketplace.routes.ts` mounted at
  `/api/v1/marketplace` in `app.ts`.
- Outbox classifier extended: `service_request.created/quoted`,
  `quotation.submitted/revised/withdrawn` are CRITICAL.
- Task 13.4 catalogue `domain` enum/types widened so providers can offer the new
  domains.

### Flutter (`Mobile/lib/features/marketplace/`)
- Datasource / repository / Riverpod state (customer + provider notifiers).
- Customer pages: browse categories, request form, requests list, request detail
  with quotation compare/accept + cancel.
- Provider pages: inbox, detail with quotation submit + job advance.
- Routes wired in `app_router.dart` (`/marketplace/*`, `/provider/marketplace/*`).

### Tests
- Backend `marketplace.test.ts` (6): catalogue, strict-details rejection, full
  lifecycle (create→quote→revise→accept→progress), concurrent single-winner
  acceptance (200 + 409), customer/non-provider isolation, cancel.
- Flutter `marketplace_test.dart` (2): browse + requests list.
- Provider/tenant suites re-run green (84) after the domain-enum widening.

### Docs
- OpenAPI: 10 `/api/v1/marketplace/*` paths added and YAML-validated.

## Verification

- `npm run typecheck` — clean.
- `vitest run marketplace` — 6/6; provider+tenant — 84/84.
- `flutter analyze lib/features/marketplace` — 0 errors.
- `flutter test marketplace_test.dart` — 2/2.
- Migrations applied 108/109/110; idempotent (guarded enum adds, `IF NOT EXISTS`,
  `ON CONFLICT DO NOTHING`).

## Addendum — mandatory initial categories

Four categories are mandatory for initial catalogue acceptance and are seeded as
separate, independently selectable entries (migrations 111–112):

1. **Wi-Fi Installation & Configuration** (`wifi_installation`, domain `networking`)
2. **Internet Installation & Connectivity** (`internet_installation`, domain `networking`)
   — kept distinct from Wi-Fi; they share network capabilities but are never merged.
3. **Solar Installation & Maintenance** (`solar_installation`, domain `solar`)
4. **Painting & Decoration** (`painting_decoration`, domain `painting`) with
   separate capabilities: interior painting, exterior painting, decorative
   finishes, wallpaper installation, surface preparation.

Strict category-specific request-detail schemas (`marketplace.schemas.ts`):
`wifiDetailsSchema`, `internetDetailsSchema`, `solarDetailsSchema`,
`paintingDetailsSchema` (all `.strict()`), selected by `categoryId` via
`detailsSchemaForCategory` and enforced by a `superRefine` cross-check so a
category only accepts its own detail keys. Networking details cover
residential/commercial, property type, rooms/coverage area, existing equipment,
new-install vs troubleshooting, preferred date, notes and photos. Solar covers
property use, new-install/maintenance, existing system, power (kW),
inverter/battery/panel, assessment date, notes and photos. Painting covers
interior/exterior, property type, area/rooms, surface preparation,
painting/wallpaper/decorative finish, date and photos.

Provider offering management and discovery work for the new domains via the
widened catalogue `domain` enum and the existing offering gate. Localization:
`categoryWifiInstallation`, `categoryInternetInstallation`,
`categorySolarInstallation`, `categoryPaintingDecoration` added (en + sw) and
used in the browse list and request form. OpenAPI categories endpoint documents
the four mandatory categories. Backend tests 7–9 assert the four categories are
separate and that strict per-category details are enforced (Wi-Fi rejects
solar-only keys; solar and painting details accepted). Flutter browse/form use
the localized names and category-specific fields.

Out of scope (not implemented): ISP infrastructure, telecom network ownership,
solar financing, advanced electrical engineering workflows.