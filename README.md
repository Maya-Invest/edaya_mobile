# Edaya Mobile

Flutter monorepo for the Edaya mobile apps, managed with [Melos](https://melos.invertase.dev/) and [pub workspaces](https://dart.dev/tools/pub/workspaces).

## Layout

```text
edaya_mobile/
├── apps/
│   ├── guardian/              edaya_guardian — parent/guardian app (production)
│   └── teacher/               edaya_teacher — Accueil-first teacher app (production)
├── packages/
│   ├── edaya_api_client/      domain-shaped Core API client
│   ├── edaya_auth/            Better Auth HTTP client
│   └── edaya_shared/          shared config, UI, auth scaffolding, and utilities
├── tooling/
│   └── integration_tests/     live API integration tests (teacher portal, shared harness)
├── scripts/                   generation, integration, design-review and release tooling
└── pubspec.yaml               workspace root (Melos config lives here)
```

### Apps

| App | Package | Audience | Notes |
|-----|---------|----------|-------|
| Guardian | `edaya_guardian` | Parents and guardians | `ca.mayainvest.edaya.guardian` — Accueil-first IA + live API; [design-language-spec](docs/specs/design-language-spec.md) |
| Teacher | `edaya_teacher` | Teachers and staff | `ca.mayainvest.edaya.staff` — Accueil-first IA + live OTP; [teacher-shell-spec](docs/specs/teacher-shell-spec.md) |

Both apps share auth, bootstrap, theme, and most UI primitives via `edaya_shared`. Each app keeps a thin layer for routes, domain features, and app-specific preferences.

## UI foundations

EDAYA UI 1.0.0 uses the [mobile design-language specification](docs/specs/design-language-spec.md), a local shared token snapshot, bundled fonts and supplied logos. The human UI brief lives in the frontend reference docs. Current review galleries are under each current app; historical proposals are unapproved feature records, not redesign instructions. `melos run verify` includes brand drift and asset checks.

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
- `HttpTransport` for origin-pinned Bearer requests against the API
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

- email OTP send + native sign-in (`/edaya/native/sign-in/email-otp`)
- sign-out
- in-memory cookie jar for identity cookies
- origin-keyed API access tokens (`getAccessToken(resource:)` / `invalidateAccessToken`)

Auth routes live under `/auth/*` and are separate from the Core API client. `POST /auth/edaya/access-token` sends `{ "resource": "<API origin>" }`. Each API origin has its own cached JWT; identity lifecycle calls use the renewal session, never an API access token.

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
await authClient.sendEmailOtp(email: 'parent@school.edu');
await authClient.signInWithEmailOtp(email: 'parent@school.edu', otp: code);

final schoolClient = createEdayaSchoolClient(
  authClient,
  getAcademicYearId: () => selectedYearId,
);
final grants = await schoolClient.effectiveGrants();
final students = await schoolClient.students.list({'schoolId': grants.schoolId});
```

Guardian and teacher wrap this in `AppSessionController` and `AppBootstrapController` from `edaya_shared`, with small app-specific hooks (grant validation, context initialization, push notifications).

The guardian inbox queries the selected guardian profile and school together with the login subject. Profile switches and sign-out clear previous results and discard pending responses for the old identity. A push-message open fetches the current authorized delivery; push payload content is not a substitute for that record.

## Local development

### API URL

Both apps default to `https://staging.api.edayaplus.com`. For local development, select the machine-local API explicitly:

| Target | API URL |
|--------|---------|
| Android emulator | `http://10.0.2.2:9999` |
| iOS simulator / desktop | `http://localhost:9999` |
| Staging | `https://staging.api.edayaplus.com` |

Set the API URL at build time:

```bash
flutter run --dart-define=API_URL=http://localhost:9999
flutter run --dart-define=API_URL=http://10.0.2.2:9999
flutter run --dart-define=API_URL=https://staging.api.edayaplus.com
```

Run these Flutter commands from `apps/guardian` or `apps/teacher`. Use an explicit staging URL when targeting staging.

The login and account screens expose **Developer settings** in all build modes (including production) to change the API URL at runtime (persisted in `SharedPreferences`). Presets include local, staging, and production. Restart the app after saving.

### Dev credentials

Use the backend `bun repo dev` server for local captured email, WhatsApp and SMS. Enable web `PUBLIC_TEST_OTP_ACCESS=true` or Flutter debug `--dart-define=TEST_OTP_ACCESS=true` for explicit Show test code and Copy controls. CI uses the separate internal testing composition and a private captured mailbox; normal staging/production builds omit testing access.

| App | Email define | Default |
|-----|--------------|---------|
| Guardian | `DEV_GUARDIAN_EMAIL` | `m.kone@mail.ci` |
| Teacher | `DEV_TEACHER_EMAIL` | `a.toure@ecole-ci.edaya.dev` |

### Run an app

```bash
(cd apps/guardian && flutter run --dart-define=API_URL=http://10.0.2.2:9999)
(cd apps/teacher && flutter run --dart-define=API_URL=http://10.0.2.2:9999)
```

## Common commands

Melos exposes workspace maintenance tasks:

| Command | Description |
|---------|-------------|
| `melos run analyze` | Static analysis across all packages |
| `melos run test` | Unit/widget tests, excluding integration, staging and design-review suites |
| `melos run format` | Format Dart code |
| `melos run fix` | Apply Dart fixes in package source and tests |
| `melos run generated:update` | Regenerate bindings (`EDAYA_OPENAPI_URL` or `EDAYA_OPENAPI_SPEC`) |
| `melos run generated:check` | Check generated bindings and mobile contracts |
| `melos run brand:generate` | Regenerate Dart tokens from the local brand snapshot |
| `melos run verify` | Release contracts, brand/generated drift, analysis, unit/widget and tooling tests |

Run specialized workflows directly from the repository root:

| Command | Description |
|---------|-------------|
| `python3 scripts/integration-runner.py` | Run and validate all live integration suites |
| `python3 scripts/integration-runner.py --suite api` | Run and validate only API integration tests |
| `python3 scripts/integration-runner.py --validate-only` | Validate existing integration results, including freshness and completeness |
| `python3 scripts/staging-smoke.py` | Staging smoke with provisioned private sessions; see [integration guidance](docs/reference/integration-testing.md) |
| `bash scripts/design-review.sh guardian` | Generate guardian screenshots using mock fixtures; use `teacher` for the teacher app |
| `python3 scripts/brand-check.py` | Check tokens, assets, contrast and visual literals |
| `bash scripts/create-android-keystore.sh` | Create Play Store upload signing configuration |
| `EDAYA_API_URL=https://api.edayaplus.com bash scripts/build-play-aab.sh` | Build release AABs for both apps; append `guardian` or `teacher` for one app |

Use `flutter clean` from an app directory when needed. `melos list` lists workspace packages.

Run package tests only:

```bash
melos exec --scope=edaya_api_client -- flutter test
melos exec --scope=edaya_auth -- flutter test
```

### Live API integration tests

Shared integration tests live in `tooling/integration_tests`. They use `edaya_auth` + `edaya_api_client` against a running API (local seed or staging).

**PR CI** resolves one backend SHA (explicit `backend_ref`, matching head branch, then PR target), verifies release contracts, starts the unified disposable API (`:9999`) and runs all three native suites. `IDENTITY_CHECKOUT_TOKEN` needs contents:read on `edaya_backend`. Artifacts contain sanitized summaries only. See [CI setup](docs/reference/ci-setup.md).

Use the backend `bun repo dev` server for local captured email, WhatsApp and SMS. Enable web `PUBLIC_TEST_OTP_ACCESS=true` or Flutter debug `--dart-define=TEST_OTP_ACCESS=true` for explicit Show test code and Copy controls. CI uses the separate internal testing composition and a private captured mailbox; normal staging/production builds omit testing access.

```bash
# With local API on :9999 and demo teacher seeded
python3 scripts/integration-runner.py

# Or run only the API suite
python3 scripts/integration-runner.py --suite api
```

Environment variables:

| Variable | Fallback | Default |
|----------|----------|---------|
| `EDAYA_API_URL` | `BASE_URL` | `http://localhost:9999` |
| `EDAYA_TEACHER_EMAIL` | `TEACHER_EMAIL` | `a.toure@ecole-ci.edaya.dev` |
| `EDAYA_ACADEMIC_YEAR_ID` | `ACADEMIC_YEAR_ID` | `2025-ci` |
| `EDAYA_CLASS_GROUP_ID` | `CLASS_GROUP_ID` | `ci-6a` |

Set `EDAYA_INTEGRATION_TESTS=1` (done automatically by `python3 scripts/integration-runner.py`). Unit test runs skip tagged integration tests.

Integration tests run against two demo-ci teacher profiles automatically:

| Profile | Email | Primary class |
|---------|-------|---------------|
| Subject teacher (ci-t1) | `a.toure@ecole-ci.edaya.dev` | `ci-6a` |
| Homeroom teacher (ci-t2) | `k.diomande@ecole-ci.edaya.dev` | `ci-6b` |

Covered API chains mirror the teacher app: bootstrap/context, calendar/timetable enrichment, evaluations, session detail (enrollments, students, attendance, logbook reads), and `recordAttendance` write-back. `EDAYA_TEACHER_EMAIL` only overrides the subject-teacher defaults when running a single profile manually.
