# Authentication API

The canonical base path is `/api/v1/auth`; `/api/auth` remains mounted for
compatibility. Responses use `{ "success": true, "message": "...", "data": {} }`
or `{ "success": false, "message": "...", "code": "..." }`.

## Registration and primary authentication

| Method | Path | Body |
|---|---|---|
| POST | `/register/email` | `firstName`, `lastName`, `email`, `password`, `role`, `termsAccepted` |
| POST | `/register/phone` | `firstName`, `lastName`, `phone`, `password`, `role`, `termsAccepted` |
| POST | `/register/phone-otp` | `firstName`, `lastName`, `phone`, `role`, `termsAccepted` |
| POST | `/verify-email/confirm` | `email`, `code` (6 digits) |
| POST | `/verify-phone/confirm` | `phone`, `otp` (6 digits) |
| POST | `/register/google` | `idToken`, optional `role` (defaults to `house_seeker`) |
| POST | `/login/email` | `email`, `password` |
| POST | `/login/phone` | `phone`, `password` |
| POST | `/login/google` | `idToken` |

### Account type (`role`) during signup

For email and phone registration, the account type is the required `role`
request field. The API currently accepts these role IDs:

`house_seeker`, `tenant`, `landlord`, `caretaker`, `property_manager`,
`letting_agent`, `moving_company`, `individual_mover`, `garbage_provider`,
`laundry_provider`, and `service_provider`.

The selected role must also exist in the database and be marked as publicly
assignable; otherwise signup returns `400` (`Invalid role selected`). For
example, a landlord signup sends `"role": "landlord"` in the JSON body.

The mobile app defaults to `"house_seeker"` and lets the user choose an account
type for email, phone, phone-OTP, and Google registration. Existing clients may
omit `role` from Google registration; it then defaults to `house_seeker`.
Google registration for an email-verified Google account continues directly to
the normal MFA enrollment or challenge response. Confirming an email address
also starts the normal MFA handoff, so the client can continue account setup
without asking the user to sign in again.

This signup role is distinct from a specialized profile category. Creating a
landlord, agency, or service-provider profile later uses the profile APIs and
requires the corresponding assigned role or authorized organization
membership; creating a profile does not itself assign a role.

Phone inputs accept Kenyan local numbers (`07...`, `01...`), country-code
(`254...`) and E.164 (`+254...`) forms. Unverified identities and disallowed
account states fail with the generic `INVALID_CREDENTIALS` response.

Successful primary authentication does not create a platform session:

```json
{
  "success": true,
  "message": "Primary authentication successful. MFA required.",
  "data": {
    "authenticationStatus": "mfa_required",
    "challengeId": "challenge-uuid",
    "availableMethods": ["totp"]
  }
}
```

For an account without MFA enrollment, the response instead contains
`authenticationStatus: "mfa_enrollment_required"` and an opaque,
short-lived `enrollmentToken`. Send it only as
`Authorization: MFA-Enrollment <token>` to `/mfa/enrollment/start`,
`/mfa/enrollment/verify`, or `/mfa/enrollment/skip`. The skip endpoint makes
MFA optional for the account until an authenticator is manually enabled later,
and issues a normal session. The token cannot authenticate to ordinary APIs.
After enrollment, sign in again and complete the independent MFA challenge.

## OTP and MFA

OTP request endpoints return the same success response for known and unknown
identities. OTPs are stored as keyed hashes, expire, and are single-use.

| Method | Path | Body |
|---|---|---|
| POST | `/login/phone-otp/request` | `phone` |
| POST | `/login/phone-otp/verify` | `phone`, `otp` |
| POST | `/login/email-otp/request` | `email` |
| POST | `/login/email-otp/verify` | `email`, `otp` |
| POST | `/mfa/challenge` | `challengeId` |
| POST | `/mfa/verify` | `challengeId`, `methodType`, `code` (legacy TOTP/recovery fields remain accepted) |
| POST | `/mfa/enrollment/start` | `methodType`, optional method fields |
| POST | `/mfa/enrollment/verify` | `mfaMethodId`, `code` |
| POST | `/mfa/enrollment/request-code` | `mfaMethodId` (restricted enrollment or bearer auth) |
| POST | `/mfa/challenge/request-code` | `challengeId`, `methodType` (`sms` or `email`) |
| POST | `/mfa/methods/request-code` | `mfaMethodId` (bearer auth; used to verify SMS/email management actions) |

With `NODE_ENV=development` (or unset) and the development email/SMS providers,
email password-reset tokens and phone signup, login, and verification codes are
printed to the server terminal for local testing. Real delivery providers and
production mode do not log codes. Verification codes are six numeric digits;
email confirmation is scoped to the email address and is rate limited. Do not
treat phone OTP as MFA completion.

## Sessions and devices

Send short-lived access credentials as `Authorization: Bearer <accessToken>`.
Web clients receive the refresh credential as an HttpOnly cookie. Mobile
clients send `{ "refreshToken": "..." }` to `POST /refresh` with
`X-Client-Platform: mobile`; that response contains a rotated token pair.
Mobile clients should keep both tokens in platform secure storage and never
place them in URLs or logs.

| Method | Path | Purpose |
|---|---|---|
| POST | `/refresh` | Rotate refresh token |
| POST | `/logout` | Revoke current refresh-token session and clear cookie |
| POST | `/logout-all` | Revoke all user sessions |
| GET | `/sessions` | List sessions |
| GET | `/sessions/current` | Get current session |
| DELETE | `/sessions/{sessionId}` | Revoke a session |
| POST | `/devices/register` | Register a device |
| GET | `/devices` | List devices |
| PATCH | `/devices/{deviceId}` | Update device |
| DELETE | `/devices/{deviceId}` | Revoke device |
| GET | `/security-events?category={security,authentication}&limit=50&offset=0` | List the signed-in user's security or authentication events |

## Account and social identity management

These account routes require an authenticated session. Password changes and
pause/deletion additionally require a recent MFA verification. For accounts
with a password credential, provide `currentPassword` for password changes and
pause/deletion; passwordless accounts confirm with recent MFA only.

| Method | Path | Purpose |
|---|---|---|
| GET | `/account/profile` | Read profile and account state |
| PATCH | `/account/profile` | Update `firstName` and/or `lastName` |
| GET | `/account/connected-accounts` | Read login identities and linked Google account |
| GET/PATCH | `/account/preferences` | Read/update language, theme, currency, timezone, formats and notification channels |
| GET/PATCH | `/account/privacy` | Read/update marketing email, analytics, ads and data-sharing choices |
| POST | `/account/email/change-request` | Request email change verification (`newEmail`) |
| POST | `/account/email/change-confirm` | Confirm a pending email change with the emailed 6-digit `token` |
| POST | `/account/phone/change-request` | Request phone change verification (`newPhone`) |
| POST | `/account/phone/change-confirm` | Confirm a pending phone change with the SMS `otp` |
| POST | `/account/data-export` | Generate and return a JSON export of account, profile, preference, session/device, notification, security, organization, property, tenancy, application, document-metadata and visit data |
| GET | `/account/status/suspension` | Read current suspension reason and status timestamp |
| GET | `/account/status/lock` | Read current lock reason and status timestamp |
| POST | `/account/password/change` | Change password with current password and recent MFA |
| POST | `/google/link` | Link Google with an authenticated session and Google ID token |
| DELETE | `/google/unlink` | Unlink Google; provide password or rely on recent MFA |
| POST | `/account/pause` | Deactivate account and revoke sessions; body includes `confirmation: "PAUSE"` and optional `currentPassword` |
| DELETE | `/account` | Mark account deleted and revoke sessions; body includes `confirmation: "DELETE"` and optional `currentPassword` |

Preference updates are persisted; notification channel toggles update the global
email/SMS/push settings used by notification delivery, and marketing email
consent is stored in the notification preferences table. Contact changes do not
replace a verified identity until its single-use email code or phone OTP has
been confirmed. Phone verification codes expire and are attempt-limited.
Contact-change requests are rate-limited per target and client IP.
Data exports are limited to five per authenticated account per hour.
Analytics, personalized-ad, and partner-sharing choices are persisted consent
flags; no analytics, advertising, or partner-sharing processor is currently
integrated in the server.

The export endpoint returns the generated JSON immediately for the authenticated
client to save/share. Uploaded document contents must be downloaded separately
through their normal authorized document flows. The export omits passwords,
access/refresh tokens, MFA secrets and push tokens. Data required for legal,
financial or tenancy retention may remain after an account deletion request.

The status detail endpoints return `reason: null` when no status change reason
was recorded. Lock expiry is currently not supported and `lockedUntil` is null.

Pausing deactivates the account; it is not a temporary sign-out. Reactivation
currently requires an authorized administrator. Account deletion is a soft
deletion marker; data subject to retention or tenancy obligations is not
hard-deleted by this endpoint.

## Administrative account management

| Method | Path | Required permission | Purpose |
|---|---|---|---|
| GET | `/admin/users` | `admin.users.view` | Search/filter users with pagination |
| GET | `/admin/users/{targetUserId}` | `admin.users.view` | View account state and login methods |
| PATCH | `/admin/users/{targetUserId}/status` | `admin.users.suspend` | Suspend, reinstate, lock, unlock, or reactivate with a reason |

Administrative account-state changes are written to `security_events`;
suspending, locking, deactivating, or deleting a user revokes their sessions.
Administrators cannot change their own status, and non-super-admins cannot
modify a super-admin account.

Cookie-authenticated unsafe requests must include an `Origin` or `Referer`
matching `CORS_ALLOWED_ORIGINS`. The same allowlist controls CORS; native
clients without cookies may omit `Origin`.

## Environment and operational requirements

- Set `CORS_ALLOWED_ORIGINS` to a comma-separated allowlist of trusted web app
  origins. Do not use wildcard origins with credentials.
- Redis is required for distributed throttling, OTP resend restrictions,
  OAuth state, and short-lived MFA enrollment transactions.
- PostgreSQL migrations are required for account status, login challenges,
  MFA, sessions, refresh tokens, device tables, account preferences, and
  pending contact-change verification (including migration `062`).
- Set `DEVICE_PUSH_TOKEN_ENCRYPTION_KEY` before accepting push tokens.
- The server emits structured JSON logs. HTTP access logs include the method,
  path (without query parameters), status, and response time; request bodies,
  authorization headers, cookies, and response bodies are not logged. Set
  `LOG_LEVEL` to control log verbosity.
- With `NODE_ENV=development` and the development email/SMS provider selected,
  verification codes, login OTPs, and password-reset tokens are printed in the
  server terminal for local testing. Never enable development mode in production;
  these authentication codes are sensitive.
- Configure `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and
  `GOOGLE_REDIRECT_URI` for Google OAuth. The browser flow uses state plus PKCE.
- Configure `EMAIL_PROVIDER` / `SMS_PROVIDER` and provider credentials to
  deliver verification messages.
- `/health` is a liveness check; `/ready` checks PostgreSQL and Redis.

Push delivery is not yet wired to notification delivery attempts; device
registration is available, but delivery provider setup alone does not enable
push notifications.

## Profile and organization APIs

These authenticated routes are mounted at `/api/v1/profile` (also available
under `/api/profile`). Profile categories are `house_seeker`, `tenant`,
`landlord`, `real_estate_agent`, `agency`, `property_manager`, `caretaker`,
`moving_service_provider`, `garbage_collection_provider`, and
`laundry_service_provider`. Profiles belong to the authenticated user; profile
types, organization membership, property ownership, tenant records, and roles
remain separate.

| Method | Path | Purpose |
|---|---|---|
| GET/PATCH | `/profile/personal` | Read/update the signed-in user's personal profile |
| POST | `/profile/uploads/image` | Upload an authenticated profile photo or logo to Cloudinary |
| GET/POST | `/profiles` | List or create the user's specialized profiles |
| GET/PATCH | `/profiles/{id}` | Read/update an owned profile or an organization profile managed by an active owner/admin |
| POST | `/profiles/{id}/submit` | Submit a complete profile for verification |
| GET/PUT | `/profiles/{id}/completion` | Return server-calculated completion (PUT also recalculates; client values are ignored) |
| GET | `/profiles/{id}/verification-records` | Read user-visible verification history (private review documents/notes are excluded) |
| GET/POST | `/profiles/{id}/verification-documents` | List or upload a private verification document for an owned profile |
| GET/POST | `/locations` | List/save the caller's private locations |
| DELETE | `/locations/{locationId}` | Clear a location owned by the caller or a manageable organization profile |
| GET | `/places/autocomplete?input=...` | Search place suggestions through the server-side Google Places key |
| GET | `/places/{placeId}` | Retrieve confirmed coordinates and address components for a selected place |
| GET/POST/PATCH/DELETE | `/service-areas/{profileId}` and `/service-areas/{areaId}` | List/create/update/delete service areas for an owned provider profile |
| GET/PUT | `/profiles/{id}/provider-extension` | Read/update provider service and business details |
| GET/PUT | `/provider-extensions/{id}/laundry-services` | Read/update laundry service choices and pickup/delivery options |
| GET/PATCH | `/organizations/{organizationId}/profile` | Read/update organization business information and office coordinates |
| POST | `/organizations/{organizationId}/profile/submit` | Submit a complete organization profile for verification |
| GET | `/organizations/{organizationId}/profile/verification-records` | Read organization verification history |
| GET/POST | `/organizations/{organizationId}/profile/verification-documents` | List or upload organization verification documents (active owners/admins only) |
| GET/POST | `/admin/verification-queue`, `/admin/profiles/{id}/review` | Review specialized profiles; requires a system administrator role |
| GET/POST | `/admin/organization-verification-queue`, `/admin/organizations/{organizationId}/review` | Review organization profiles; requires a system administrator role |
| GET | `/admin/profiles/{id}/verification-documents`, `/admin/organizations/{organizationId}/verification-documents` | List private review documents; system administrator only |
| GET | `/verification-documents/{documentId}/download-url` | Issue a five-minute private signed URL to the profile owner or organization owner/admin |
| GET | `/admin/verification-documents/{documentId}/download-url` | Issue a five-minute private signed URL to a system administrator reviewer |

Image uploads use `multipart/form-data` with a `file` field and a `kind` of
`personal_photo`, `profile_photo`, `business_logo`, or `organization_logo`.
Specialized-profile uploads also require `profileId`; organization-logo uploads
require `organizationId`. Uploads are limited to JPEG, PNG, or WebP files up to
5 MB. The server verifies file signatures and ownership before sending the
image to Cloudinary. Cloudinary credentials are server-only environment values:
`CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET`.
Configure all three in the server's ignored `.env`; do not put the API secret
in the mobile app or commit it. On startup, the server logs the Cloudinary
status as `not_configured`, `connected` (after a credential check), or
`disconnected`. A Cloudinary connection failure does not stop the API server,
but image uploads will not work until connectivity and credentials are valid.

Profile and organization mutations validate input, verify ownership or active
organization membership, and write administrative audit events. Organization
profiles may be edited only by active owners/admins; ordinary active members
may read the organization profile. Registration and tax identifiers are
withheld from ordinary organization members. Completing or approving a profile
does not grant a role, property assignment, ownership, tenant record, or access
to operational data. Creating a specialized profile requires the corresponding
assigned role; an agency profile additionally requires an active owner/admin
membership in a letting-agency organization. A tenant profile does not create a
tenant/tenancy record.

`POST /locations` accepts validated latitude/longitude and a
`locationSource` (`device_gps`, `manual_map_pin`, `address_search`, or
`text_entry`). Personal residential locations are private to the account and
are separate from profile-specific office/provider locations. Business and
provider locations require a profile ID; property locations are not writable
through this profile API. There is no public profile/location endpoint and no
background location tracking.

Completion requirements are calculated by the server per category. A provider
must have its provider details and at least one active service area before
submitting; laundry providers must also select at least one offered service.
Organization verification requires business name, description, a contact
method, office address, and confirmed coordinates. Editing a verified or
submitted profile returns it to draft/pending verification. Rejected profiles
can be edited and resubmitted.

### Maps and media configuration

The Flutter location picker uses `google_maps_flutter` and requests
foreground-only location permission through `geolocator` when the user
explicitly taps **Use my current location**. Map display/pin placement is
enabled with `--dart-define=GOOGLE_MAPS_ENABLED=true`. Configure a
client-side key restricted to the Android application ID and signing
certificate, and to the iOS bundle ID; enable the corresponding Google Maps
SDKs in the Google project. For Android, add
`GOOGLE_MAPS_API_KEY=<restricted-client-key>` to the ignored
`Mobile/android/local.properties`. For iOS, copy
`Mobile/ios/Flutter/Maps.xcconfig.example` to the ignored
`Mobile/ios/Flutter/Maps.xcconfig` and set `GOOGLE_MAPS_API_KEY` there. Never
use a server credential as a mobile Maps key. Without a configured key, users
can still save manually entered coordinates or explicitly requested device
coordinates. Place search uses the backend `/places/autocomplete` and
`/places/{placeId}` endpoints. Configure `GOOGLE_MAPS_SERVER_API_KEY` in the
ignored server `.env` with a key restricted to Places API (New); the key is
never sent to Flutter. The API returns an unavailable response when the key
is absent or Google is unreachable, and the picker retains manual pin,
coordinate, and text entry. Selected place coordinates and available country,
county, city, neighborhood, address, and place ID are saved as confirmed
location metadata.

### Nearby properties, directions, and location sharing

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/listings/nearby` | Search published, coordinate-backed listings by center/radius, map bounds, or locality text |
| POST | `/api/v1/listings/directions` | Calculate a route through the server-side Routes API key |
| GET | `/api/v1/location-sharing/eligible-visits` | List site visits with another registered user where purpose-bound sharing is allowed |
| POST | `/api/v1/location-sharing/sessions` | Start explicit sharing with the other participant in a scheduled or confirmed site visit |
| PATCH | `/api/v1/location-sharing/sessions/{sessionId}/location` | Publish the latest foreground location, throttled to at most once every 15 seconds |
| GET | `/api/v1/location-sharing/sessions` | List the caller's sessions without returning location coordinates |
| GET | `/api/v1/location-sharing/shared-with-me` | List active location shares addressed to the caller |
| GET | `/api/v1/location-sharing/sessions/{sessionId}/location` | Read a current coordinate only as the selected recipient |
| POST | `/api/v1/location-sharing/sessions/{sessionId}/stop` | Revoke a session and erase its current coordinate immediately |
| GET | `/api/v1/location-sharing/providers?latitude=...&longitude=...` | Find approved moving, laundry, and waste providers whose active radius areas cover a point |

Nearby results include published property data and approximate coordinates rounded
to three decimal places; they do not return the street address. Only published
properties with vacant units are included. Search supports rent and bedroom
filters. Searches use a coordinate bounding filter and Haversine distance,
supported by B-tree indexes;
PostGIS is not required. Route calculations require `GOOGLE_ROUTES_API_KEY`, a
server-only key restricted to Routes API. Until configured, the route endpoint
returns a configuration error and the mobile app offers external navigation.

Sharing is limited to the other registered person on a scheduled or confirmed
site visit. Sessions expire after 15, 30, 60, or at most 480 minutes. The backend
keeps only the latest coordinate, throttles updates, authorizes every read,
audits start/stop without coordinates, clears expired coordinates, and removes
expired session metadata after 90 days. The Flutter client starts GPS only after
the user chooses a session, stops when the screen closes or the app backgrounds,
and does not request background permission.

Cloudinary is used only for public profile photos and logos. Verification
documents are stored in a private S3 bucket, with file metadata and SHA-256
hashes in PostgreSQL. Uploads accept PDF, JPEG, PNG, or WebP files up to
10 MB; content signatures are checked. Downloads use five-minute signed URLs
after profile-owner, organization-owner/admin, or system-administrator checks,
and access attempts are logged. Configure `AWS_REGION`,
`AWS_S3_PRIVATE_BUCKET`, and an AWS IAM role or credentials in server runtime
configuration. The bucket must block public access and allow the server role
only the required `s3:PutObject`, `s3:GetObject`, and `s3:DeleteObject`
permissions. The API returns 503 while private storage is not configured.
Malware scanning is not present in this repository, so production deployment
should add scanning before accepting verification evidence.

Migration `063_complete_profile_foundations.sql` adds organization office
coordinates, service-area radius/descriptions, verification history, and
lookup indexes. Migration `064_profile_verification_documents.sql` adds
private verification-document metadata and access auditing. Both are applied
to the current development database; deploy them through the normal migration
process in other environments.
