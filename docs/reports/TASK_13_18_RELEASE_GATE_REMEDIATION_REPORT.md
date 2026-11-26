# Task 13.18 — Release Gate Remediation Report

## 1. Repository baseline (preserved)
- Branch `main`, HEAD `b550497`. Working tree **82 modified, 274 untracked**
  (Tasks 13.15–13.17 uncommitted work preserved). No `git reset`/`clean`/revert;
  no commits; debug artifacts left in place (documented for removal).

## 2. Root cause of C-1
`canAccessPropertyDocument` granted access to **anyone with property access**
when no `requiredPermission` was supplied, ignoring the document's own
`visibility`, `allowed_roles`, `allowed_user_ids`, `allowed_organisation_ids`,
status and expiry. A `findPropertyDocumentsByTenancy` lookup was performed but
its result unused. This made private/restricted property documents readable by
any tenant/caretaker/manager/org member with property access (IDOR-adjacent).

## 3. Authorization rules implemented
New `computeDocumentVisibilityAccess(userId, document)` (exported) resolves the
caller's real relationships from the DB for the document's actual property and
fails closed on missing/malformed data:
- Gates: `status = active`, not expired, known `visibility`, `userId` present.
- Relationships: uploader; active property ownership; active property
  assignment (manager); unit/caretaker assignment **scoped to the document's
  unit**; active tenancy participation; active organization membership; explicit
  allow-list (`allowed_user_ids` / `allowed_organisation_ids` / `allowed_roles`
  via org role ids).
- Visibility matrix: `private`→uploader only; `owner`→uploader/owner;
  `manager`→management; `tenant`→management/tenant/unit-staff;
  `participant`→management/tenant/unit-staff/listed; `organization`→management/
  org member/allowed org; `public`→any authenticated.
- `requiredPermission` (management endpoints) must ALSO pass `authorize()`.
- No client-supplied ids/roles trusted; revoked/expired assignments and removed
  allow-list entries deny immediately (read live from DB).

## 4. Document-access paths covered
All reads funnel through `canAccessPropertyDocument`:
- `requireDocumentAccess` middleware (GET/PATCH/DELETE `/documents/:id`,
  `/documents/:id/signed-url`).
- `getPropertyDocument` controller.
- Signed-URL issuance (`generateDocumentSignedUrl`) — gated before signing.
- Signed-URL redemption (`accessDocumentViaSignedUrl`) — now re-authorizes via
  `canAccessDocumentViaSignedUrl` → `canAccessPropertyDocument(payload.userId)`,
  closing C-2 (revocation effective at redemption, bounded by token TTL).

## 5. Regression tests added (21/21 pass)
`server/src/modules/auth/document-authorization.test.ts` covers:
1 uploader-private, 2 owner, 3 manager, 4 caretaker(unit), 5 tenant, 6 listed
participant, 7 private-denied-to-manager, 8 allow-list grant, 9 allow-list
deny, 10 removed allow-list, 11 revoked assignment, 12 expired staff, 13
cross-property substitution, 14 cross-org, 15 unauthenticated, 16
malformed/missing visibility (fail closed), 17 expired doc, 18 archived doc,
plus HTTP: GET doc owner-200/outsider-403, signed-url issuance denied (403),
signed-URL redemption re-authz + revocation (C-2). Test env gained a placeholder
`JWT_PRIVATE_KEY` (test-setup) to exercise signing.

## 6. Provider navigation changes
- `provider_dashboard_page.dart`: added **Provider setup** (onboarding,
  organizations, services, locations, service-areas, availability),
  **Marketplace** (provider requests), **Operations** (moving, garbage, laundry,
  home maintenance, cleaning, installation, finishing) entry points — all to
  existing routes. Role/org context preserved (staff workload still org-only);
  backend authz enforced (unauthorized → 403 error state).
- `dashboard_page.dart`: "For providers" now has **Provider onboarding & setup**
  (→ `/provider/onboarding`) and **Open provider dashboard**
  (→ `/provider/dashboard`) so an incomplete provider can discover setup without
  the dashboard API succeeding.

## 7. Explore & Visits decisions
Both had real implemented destinations, so they were connected (not deferred):
- **Explore** → `/house-seeker/search` ("Browse homes").
- **Visits** → `/house-seeker/visits` ("View site visits").
No new marketplace/site-visit functionality added; "Coming soon" removed.

## 8. C-2 / C-3 / C-4 review
- **C-2 (Medium) — FIXED.** Signed-URL redemption re-authorizes; proven by the
  revocation test. Residual: token valid up to 1h TTL (acceptable, documented).
- **C-3 (Low) — FIXED.** Pino `redact` paths for authorization/cookie/password/
  otp/code/token/accessInstructions in both dev and prod loggers.
- **C-4 (Medium) — OPEN, non-blocking.** Operational (cleaning/installation/
  finishing) attachments store a free-form `document_id` (no FK/ownership
  binding, no MIME/size check) and return the id to customers. Not a direct file
  leak — download remains authz-gated by property-document rules. Remediation:
  add FK/ownership + MIME/size validation and stop returning internal ids.

## 9. Localization changes
Added provider-nav keys (en+sw) and regenerated. House-seeker placeholders/
`noHomesMatch` were fixed in 13.17. Broader `app_sw.arb` untranslated strings and
hard-coded provider/dashboard/profile strings remain (documented, separate work).

## 10. Verification results
- Backend `tsc --noEmit`: clean.
- `document-authorization.test.ts`: 21/21.
- Regression batch (auth, tenancy, landlord, house-seeker, rental, profile,
  account): 270/270.
- Provider/app batch (document-authz, provider, provider-platform, app,
  error-handler): 65/65.
- Flutter `flutter analyze`: 0 errors.
- Flutter full suite: **244/244** (incl. 5 nav + 1 provider-dashboard test).
- OpenAPI: 319 paths, 0 dangling refs. Migrations: pending 0 (no schema change).

## 11. Remaining limitations
C-4 (medium, attachments); broad Swahili/hard-coded l10n; load performance not
benchmarked; debug artifacts to remove; dead legacy `/dashboard` handler
(shadowed, informational); category→module routing is convention-based.

## 12. Updated release-readiness checklist
See `PROVIDER_PLATFORM_RELEASE_READINESS_CHECKLIST.md` (13.18 update): C-1 gate
now PASS, nav gate now PASS; C-4 documented medium.

## 13. Final verdict
**REMEDIATION COMPLETE — READY FOR FINAL RELEASE REASSESSMENT.**
C-1 is fixed and demonstrated by 21 passing authorization regression tests;
provider navigation and Explore/Visits are reachable through normal flows with
passing Flutter tests. This does not itself authorize controlled beta; a separate
final reassessment must confirm all gates (C-4, l10n, perf, hygiene) are closed.