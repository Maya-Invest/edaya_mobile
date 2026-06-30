# Edaya Mobile

Flutter monorepo for the Edaya mobile apps, managed with [Melos](https://melos.invertase.dev/) and [pub workspaces](https://dart.dev/tools/pub/workspaces).

## Layout

```text
edaya_mobile/
├── apps/
│   ├── guardian/              edaya_guardian — parent/guardian app
│   └── teacher/               edaya_teacher — teacher & classroom app
├── packages/
│   ├── edaya_api_client/      domain-shaped Core API client
│   ├── edaya_auth/            Better Auth HTTP client
│   └── edaya_shared/          shared config, UI, auth scaffolding, and utilities
├── scripts/                   OpenAPI binding generation helpers
└── pubspec.yaml               workspace root (Melos config lives here)
```

### Apps

| App | Package | Audience | Notes |
|-----|---------|----------|-------|
| Guardian | `edaya_guardian` | Parents and guardians | `com.softilab.edaya.guardian` — calendar, academic records, fees, inbox, student switching; Firebase push |
| Teacher | `edaya_teacher` | Teachers and staff | `com.softilab.edaya.staff` — calendar, evaluations, attendance; class filter |

Both apps share auth, bootstrap, theme, and most UI primitives via `edaya_shared`. Each app keeps a thin layer for routes, domain features, and app-specific preferences.

## Prerequisites

- Flutter stable (Dart SDK ^3.11)
- Melos (`dart pub global activate melos`)

## Setup

From this directory:

```bash
dart pub get
melos bootstrap
```

## Shared packages

### `edaya_shared`

Cross-app Flutter code used by guardian and teacher:

- **Config** — `ApiBaseUrlConfig` (compile-time `--dart-define=API_URL` plus debug-only runtime override), `DevApiUrlSettings`
- **UI** — `PersonAvatar`, `DataState`, `RouteErrorPage`, `AccountSheetBody`, `ModalBottomSheetPage`, `AppTheme`
- **App scaffolding** — `EdayaAppRoot`, `EdayaRootScope`, `EdayaRouterRefresh`, `registerEdayaDependencies`, `createEdayaSchoolClient`
- **Auth** — `AuthSessionStorage`, `AppSessionController`, `AppBootstrapController`, `LoginPage` / `LoginController`
- **Utils** — date/time formatting, shared entity query helpers (`entitiesByIds`, scope builders, etc.)

Import from a single entry point:

```dart
import 'package:edaya_shared/edaya_shared.dart';
```

App-specific code (routes, feature controllers, extra `SessionStorage` keys, push implementations) stays under each app’s `lib/`.

### `edaya_api_client`

Mirrors the TypeScript `@edaya/api-client` package:

- `Transport` abstraction for HTTP
- `createSchoolClient()` with generated entity/command/query bindings
- `HttpTransport` for cookie-aware requests against the API
- Typed `EffectiveGrantsResponse` for `/core/authorization/effective-grants`

Bindings are generated from the published OpenAPI document (`info.x-edaya-client-bindings`).

From a URL (CI-friendly — no `edaya` checkout required):

```bash
EDAYA_OPENAPI_URL=https://api.example.com/doc melos run generated:update
```

From a local OpenAPI file:

```bash
EDAYA_OPENAPI_SPEC=/path/to/openapi.json melos run generated:update
```

This updates `packages/edaya_api_client/spec/client-bindings.json` and the Dart files under `lib/src/generated/`. Commit all three when the API contract changes.

Offline drift check (uses the committed bindings spec only):

```bash
melos run generated:check
```

Full workspace verification:

```bash
melos run verify
```

### `edaya_auth`

Better Auth client for mobile sign-in flows:

- email + password sign-in
- email OTP sign-in
- sign-up and sign-out
- in-memory cookie jar for session cookies

Auth routes live under `/auth/*` and are separate from the Core API client.

## Wiring auth + API in an app

At runtime, apps resolve the API base URL through `ApiBaseUrlConfig`, register shared clients with Levit, and build a school client from the authenticated session:

```dart
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';

// Called in main() before runApp:
await ApiBaseUrlConfig.load();

// Registered once in the app DI module:
registerEdayaDependencies(scope, cookieJar: cookieJar);

final authClient = scope.find<AuthClient>();
await authClient.signInWithEmail(email: 'parent@school.edu', password: 'secret');

final schoolClient = createEdayaSchoolClient(
  authClient,
  getAcademicYearId: () => selectedYearId,
);
final grants = await schoolClient.effectiveGrants();
final students = await schoolClient.students.list({'schoolId': grants.schoolId});
```

Guardian and teacher wrap this in `AppSessionController` and `AppBootstrapController` from `edaya_shared`, with small app-specific hooks (grant validation, context initialization, push notifications).

## Local development

### API URL

Default compile-time URL is `https://api-staging.edaya.softilab.dev`. Override at build time:

```bash
flutter run --dart-define=API_URL=http://localhost:9999          # local API
flutter run --dart-define=API_URL=http://10.0.2.2:9999           # Android emulator → local
flutter run --dart-define=API_URL=http://192.168.1.10:9999       # LAN device → local
```

Or use Melos shortcuts:

```bash
melos run run:guardian:local
melos run run:teacher:local
```

In **debug** builds, the login and account screens also expose **Developer settings** to change the URL at runtime (persisted in `SharedPreferences`). A **Staging** preset is available there. Restart the app after saving.

### Dev credentials

Optional `--dart-define` values pre-fill the login form:

| App | Email define | Default |
|-----|--------------|---------|
| Guardian | `DEV_GUARDIAN_EMAIL` | `c.laurent@mail.com` |
| Teacher | `DEV_STAFF_EMAIL` | `m.dupont@school.edu` |
| Both | `DEV_PASSWORD` | `DevPassword1!` |

### Run an app

```bash
cd apps/guardian && flutter run
cd apps/teacher && flutter run
```

## Common commands

| Command | Description |
|---------|-------------|
| `melos run analyze` | Static analysis across all packages |
| `melos run test` | Run tests in all packages/apps |
| `melos run format` | Format Dart code |
| `melos run generated:update` | Regenerate bindings (`EDAYA_OPENAPI_URL` or `EDAYA_OPENAPI_SPEC`) |
| `melos run generated:check` | Verify generated Dart matches `spec/client-bindings.json` |
| `melos run verify` | `generated:check` + analyze + test |
| `melos run clean:flutter` | Run `flutter clean` in all apps |
| `melos run android:keystore:create` | Create upload keystore for Play Store signing |
| `melos run build:play:aab` | Build release AABs for guardian + teacher |
| `melos list` | List workspace packages |

Run package tests only:

```bash
melos exec --scope=edaya_api_client -- flutter test
melos exec --scope=edaya_auth -- flutter test
```
