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
├── tooling/
│   └── integration_tests/     live API integration tests (teacher portal, shared harness)
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

- **Config** — `ApiBaseUrlConfig` (compile-time `--dart-define=API_URL` plus runtime override in all build modes), `DevApiUrlSettings`, `DeveloperSettingsConfig`
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

Bindings are generated from the published OpenAPI document (`x-edaya-*` operation extensions on core routes).

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

Default API URL depends on the app (no `--dart-define` needed for local dev):

| App | Default | Use when |
|-----|---------|----------|
| Guardian | `http://10.0.2.2:9999` | Android emulator → machine-local API |
| Teacher | `http://localhost:9999` | iOS simulator / desktop → local API |

Override at build time:

```bash
flutter run --dart-define=API_URL=http://localhost:9999          # local API
flutter run --dart-define=API_URL=http://10.0.2.2:9999           # Android emulator → local
flutter run --dart-define=API_URL=http://192.168.1.10:9999       # LAN device → local
flutter run --dart-define=API_URL=https://staging.api.edayaplus.com
```

Or use Melos shortcuts:

```bash
melos run run:guardian:local   # explicit Android emulator URL
melos run run:teacher:local    # explicit localhost
```

The login and account screens expose **Developer settings** in all build modes (including production) to change the API URL at runtime (persisted in `SharedPreferences`). Presets include local, staging, and production. Restart the app after saving.

### Dev credentials

Optional `--dart-define` values pre-fill the login form:

| App | Email define | Default |
|-----|--------------|---------|
| Guardian | `DEV_GUARDIAN_EMAIL` | `m.kone@mail.ci` |
| Teacher | `DEV_STAFF_EMAIL` | `a.toure@ecole-ci.edaya.dev` |
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
| `melos run test:integration` | Live API integration tests (`EDAYA_INTEGRATION_TESTS=1`) |
| `melos run clean:flutter` | Run `flutter clean` in all apps |
| `melos run android:keystore:create` | Create upload keystore for Play Store signing |
| `melos run build:play:aab` | Build release AABs for guardian + teacher |
| `melos list` | List workspace packages |

Run package tests only:

```bash
melos exec --scope=edaya_api_client -- flutter test
melos exec --scope=edaya_auth -- flutter test
```

### Live API integration tests

Shared integration tests live in `tooling/integration_tests`. They use `edaya_auth` + `edaya_api_client` against a running API (local seed or staging).

```bash
# With local API on :9999 and demo teacher seeded
melos run test:integration

# Or via the legacy shell entrypoint
./scripts/teacher-mobile-smoke.sh
```

Environment variables:

| Variable | Fallback | Default |
|----------|----------|---------|
| `EDAYA_API_URL` | `BASE_URL` | `http://localhost:9999` |
| `EDAYA_TEACHER_EMAIL` | `TEACHER_EMAIL` | `a.toure@ecole-ci.edaya.dev` |
| `EDAYA_TEACHER_PASSWORD` | `TEACHER_PASSWORD` | `DevPassword1!` |
| `EDAYA_ACADEMIC_YEAR_ID` | `ACADEMIC_YEAR_ID` | `2025-ci` |
| `EDAYA_CLASS_GROUP_ID` | `CLASS_GROUP_ID` | `ci-6a` |

Set `EDAYA_INTEGRATION_TESTS=1` (done automatically by `melos run test:integration`). Unit test runs skip tagged integration tests.

Integration tests run against two demo-ci teacher profiles automatically:

| Profile | Email | Primary class |
|---------|-------|---------------|
| Subject teacher (ci-t1) | `a.toure@ecole-ci.edaya.dev` | `ci-6a` |
| Homeroom teacher (ci-t2) | `k.diomande@ecole-ci.edaya.dev` | `ci-6b` |

Covered API chains mirror the teacher app: bootstrap/context, calendar/timetable enrichment, evaluations, session detail (enrollments, students, attendance, logbook reads), and `recordAttendance` write-back. `EDAYA_TEACHER_EMAIL` only overrides the subject-teacher defaults when running a single profile manually.
