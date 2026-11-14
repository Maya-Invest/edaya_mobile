# Edaya Mobile

Flutter monorepo for the Edaya mobile apps, managed with [Melos](https://melos.invertase.dev/) and [pub workspaces](https://dart.dev/tools/pub/workspaces).

## Releases

Android and iOS releases build `apps/guardian` and `apps/teacher`. Production qualification feeds Google Play internal testing and Apple TestFlight; public releases use separate manual workflows. See [CI setup](docs/reference/ci-setup.md), [Google Play](docs/reference/google-play-releases.md), and [Apple release credentials](docs/reference/apple-releases.md).

## Layout

```text
edaya_mobile/
├── apps/
│   ├── guardian/              parent/guardian release app
│   └── teacher/               teacher release app
├── packages/
│   ├── edaya_api_client/      domain-shaped Core API client
│   ├── edaya_auth/            Better Auth HTTP client
│   └── edaya_shared/          shared config, UI, auth scaffolding, and utilities
├── tooling/
│   └── integration_tests/     live API integration tests (teacher portal, shared harness)
├── tooling/repo/              Dart generation, integration, design-review and release tooling
└── pubspec.yaml               workspace root (Melos config lives here)
```

### Apps

| App | Package | Audience | Notes |
|-----|---------|----------|-------|
| Guardian | `edaya_guardian_v2` | Parents and guardians | `ca.mayainvest.edaya.guardian` — Accueil-first IA + live API; [design-language-spec](docs/specs/design-language-spec.md) |
| Teacher | `edaya_teacher_v2` | Teachers and staff | `ca.mayainvest.edaya.teacher` — Accueil-first IA + live OTP; [teacher-shell-spec](docs/specs/teacher-shell-spec.md) |

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

Bindings are generated from one immutable backend checkout, including school and authentication routes. Preparation is required before analysis or builds on a clean checkout:

```sh
flutter pub get
dart run edaya_repo:repo generate client staging
flutter pub get --enforce-lockfile
dart run edaya_repo:repo ci verify
```

Use `--ref <branch-or-commit>` for explicit local validation or `--backend-root <clean-checkout>` for an existing detached backend. Generated Dart files and `.generated/client-bindings.json` are ignored build inputs. Do not commit snapshots. See [CI setup](docs/reference/ci-setup.md) for branch selection, independent releases and signing.

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

Use the backend `bun repo dev` server for local captured email, WhatsApp and SMS. Teacher_v2 debug builds fill the verification field automatically when the local server advertises test OTP access. Tap Verify to submit. Web and other Flutter clients use explicit Show test code and Copy controls with `PUBLIC_TEST_OTP_ACCESS=true` or `--dart-define=TEST_OTP_ACCESS=true` respectively. CI uses the separate internal testing composition and a private captured mailbox; normal staging/production builds omit testing access.

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
| `melos run generated:update` | Acquire backend staging and generate the ignored client |
| `melos run generated:check` | Check generated bindings and mobile contracts |
| `melos run brand:generate` | Regenerate Dart tokens from the local brand snapshot |
| `melos run verify` | Prepared client, brand integrity, analysis, unit/widget and tooling tests |

Run specialized workflows directly from the repository root:

| Command | Description |
|---------|-------------|
| `dart run edaya_repo:repo test integration` | Run and validate all live integration suites |
| `dart run edaya_repo:repo test integration api` | Run and validate only API integration tests |
| `dart run edaya_repo:repo ci validate-integration` | Validate existing integration results, including freshness and completeness |
| `dart run edaya_repo:repo maintenance smoke` | Staging smoke with provisioned private sessions; see [integration guidance](docs/reference/integration-testing.md) |
| `dart run edaya_repo:repo maintenance design-review guardian` | Generate guardian screenshots using mock fixtures; use `teacher` for the teacher app |
| `dart run edaya_repo:repo check` | Check tokens, assets, contrast and visual literals |
| `dart run edaya_repo:repo maintenance keystore` | Create Play Store upload signing configuration |
| `dart run edaya_repo:repo build production` | Build release AABs for both apps; both applications are always required |

Use `flutter clean` from an app directory when needed. `melos list` lists workspace packages.

Run package tests only:

```bash
melos exec --scope=edaya_api_client -- flutter test
melos exec --scope=edaya_auth -- flutter test
```

### Live API integration tests

Shared integration tests live in `tooling/integration_tests`. They use `edaya_auth` + `edaya_api_client` against a running API (local seed or staging).

**PR CI** resolves one backend destination commit, generates both contracts, starts that exact backend and runs API, guardian and teacher integrations. `BACKEND_CHECKOUT_TOKEN` needs backend contents:read. See [CI setup](docs/reference/ci-setup.md).

Use the backend `bun repo dev` server for local captured email, WhatsApp and SMS. Teacher_v2 debug builds fill the verification field automatically when the local server advertises test OTP access. Tap Verify to submit. Web and other Flutter clients use explicit Show test code and Copy controls with `PUBLIC_TEST_OTP_ACCESS=true` or `--dart-define=TEST_OTP_ACCESS=true` respectively. CI uses the separate internal testing composition and a private captured mailbox; normal staging/production builds omit testing access.

```bash
# With local API on :9999 and demo teacher seeded
dart run edaya_repo:repo test integration

# Or run only the API suite
dart run edaya_repo:repo test integration api
```

Environment variables:

| Variable | Fallback | Default |
|----------|----------|---------|
| `EDAYA_API_URL` | `BASE_URL` | `http://localhost:9999` |
| `EDAYA_TEACHER_EMAIL` | `TEACHER_EMAIL` | `a.toure@ecole-ci.edaya.dev` |
| `EDAYA_ACADEMIC_YEAR_ID` | `ACADEMIC_YEAR_ID` | `2025-ci` |
| `EDAYA_CLASS_GROUP_ID` | `CLASS_GROUP_ID` | `ci-6a` |

Set `EDAYA_INTEGRATION_TESTS=1` (done automatically by `dart run edaya_repo:repo test integration`). Unit test runs skip tagged integration tests.

Integration tests run against two demo-ci teacher profiles automatically:

| Profile | Email | Primary class |
|---------|-------|---------------|
| Subject teacher (ci-t1) | `a.toure@ecole-ci.edaya.dev` | `ci-6a` |
| Homeroom teacher (ci-t2) | `k.diomande@ecole-ci.edaya.dev` | `ci-6b` |

Covered API chains mirror the teacher app: bootstrap/context, calendar/timetable enrichment, evaluations, session detail (enrollments, students, attendance, logbook reads), and `recordAttendance` write-back. `EDAYA_TEACHER_EMAIL` only overrides the subject-teacher defaults when running a single profile manually.

Guardian v2 is available in `apps/guardian`, with a child picker, two Home menu groups and unified period results. See [its workspace specification](docs/specs/guardian-v2-workspace-spec.md).
