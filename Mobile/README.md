# GetKeja Mobile

## UI theme

The mobile app uses Flutter Material 3 with shared GetKeja colors, typography
scale, form controls, buttons, cards, and navigation styling from `AppTheme`.
The Inter variable font is bundled from Google Fonts under its SIL Open Font
License; see `assets/fonts/OFL.txt`. Screens should use the theme's text styles
and component defaults instead of defining independent styles.

## API configuration

Every mobile build must set `API_BASE_URL` to the actual backend address. The
app does not fall back to emulator or localhost ports, so a missing setting
fails clearly instead of sending requests to a guessed endpoint. For a
physical Android device connected over USB, forward the backend's host port
and use the device's loopback address. The commands below use port `4000`,
which is the current local backend configuration; replace it if
`SERVER_PORT` (Docker Compose) or `PORT` (direct server process) is different:

```sh
adb reverse tcp:4000 tcp:4000
flutter run -d <device-id> --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

For a physical device on Wi-Fi, use the development machine's LAN address and
the backend's configured host port. Make sure the backend listens on the
network interface:

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000
```

Set `API_BASE_URL` to the deployed HTTPS API when building a release. Release
builds reject non-HTTPS API URLs.

## Authentication

The auth client calls `/api/v1/auth`. It sends access tokens as bearer
credentials and rotates refresh tokens through the refresh endpoint. Both
tokens are stored using platform secure storage. The client models the
`mfa_required`, `mfa_enrollment_required`, and verification-required responses;
it never treats successful primary authentication as a completed sign-in.
Enrollment requests use a restricted temporary MFA transaction token, not an
application access token. The profile tab provides the existing sign-in and
create-account entry points.

Password reset email delivery is not configured on the server yet. Development
and test servers return a reset token for the app's reset form; production
requires an email provider before users can receive reset instructions.

## Google sign-in

Configure Android and iOS OAuth clients for the app's package/bundle IDs and
provide the Google **web/server client ID** to the Flutter build:

```sh
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

Configure the corresponding allowed client ID on the server using its
`GOOGLE_CLIENT_ID`/`GOOGLE_ALLOWED_CLIENT_IDS` settings. The mobile app only
needs the public client ID; never put a Google client secret in the app.

## Profile location maps

Enable the Google Maps picker at build time with
`--dart-define=GOOGLE_MAPS_ENABLED=true`. Create a mobile Maps SDK key restricted
to Android package `com.getkeja.mobile.a7c29f` and its signing certificate,
and iOS bundle ID `com.getkeja.getKejaMobile`. Enable Maps SDK for Android and
Maps SDK for iOS in the Google Cloud project. Put the Android key in the
ignored `android/local.properties` as `GOOGLE_MAPS_API_KEY=...`; copy
`ios/Flutter/Maps.xcconfig.example` to the ignored `ios/Flutter/Maps.xcconfig`
and set the property there. Use separate restricted keys per platform.

Place autocomplete uses the backend. Configure `GOOGLE_MAPS_SERVER_API_KEY`
in the server environment with a key restricted to Places API (New). Do not
reuse the mobile key or commit any key. Without a server key, users can still
pin a map location, enter coordinates, or save a text address. Google Cloud
project credentials are required to create the restricted keys; this checkout
does not contain them.

## Nearby property search and directions

The authenticated mobile search uses `GET /api/v1/listings/nearby` against
published properties with vacant units. Radius and map-bounds searches use
stored coordinates; text searches also include properties without coordinates.
It supports radius searches,
visible map bounds, and text matching for listing names and localities. Returned
map coordinates are rounded to about 100 metres and the full street address is
not returned by this discovery endpoint. There is no PostGIS dependency; the
database uses coordinate bounding filters and a Haversine distance calculation.

Route previews are provided by the authenticated
`POST /api/v1/listings/directions` endpoint. Configure `GOOGLE_ROUTES_API_KEY`
on the server, restricted to Routes API, to enable it. The app can also hand a
property destination to an installed navigation app; it does not claim to run
turn-by-turn navigation itself. The map canvas requires the restricted Android
or iOS Maps SDK key described above. Text and list search remain available
without Maps credentials.

Future service modules can use the authenticated
`GET /api/v1/location-sharing/providers` endpoint to find approved moving,
laundry, and waste-service profiles whose active radius areas cover a point.
It returns provider business details, matching area, and approximate distance;
it does not return tenant or property-owner records.
