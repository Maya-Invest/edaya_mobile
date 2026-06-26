# Edaya Mobile

Flutter monorepo for the Edaya mobile apps, managed with [Melos](https://melos.invertase.dev/) and [pub workspaces](https://dart.dev/tools/pub/workspaces).

## Layout

```text
mobile/
├── apps/
│   ├── guardian/              edaya_guardian — parent/guardian app
│   └── teacher/               edaya_teacher — teacher & classroom app
├── packages/
│   ├── edaya_api_client/      domain-shaped Core API client
│   └── edaya_auth/            Better Auth HTTP client
└── pubspec.yaml               workspace root (Melos config lives here)
```

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

### `edaya_api_client`

Mirrors the TypeScript `@edaya/api-client` package:

- `Transport` abstraction for HTTP
- `createSchoolClient()` with generated entity/command/query bindings
- `HttpTransport` for cookie-aware requests against the API
- Typed `EffectiveGrantsResponse` for `/core/authorization/effective-grants`

Bindings are generated from the API registry when you run the repo root command:

```bash
bun run openapi:generate
```

### `edaya_auth`

Better Auth client for mobile sign-in flows:

- email + password sign-in
- email OTP sign-in
- sign-up and sign-out
- in-memory cookie jar for session cookies

Auth routes live under `/auth/*` and are separate from the Core API client.

## Wiring auth + API in an app

```dart
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';

final authClient = AuthClient(baseUrl: 'https://api.example.com');

await authClient.signInWithEmail(
  email: 'parent@school.edu',
  password: 'secret',
);

final apiTransport = HttpTransport(
  baseUrl: 'https://api.example.com',
  cookieHeader: () => authClient.cookieHeader,
  getAcademicYearId: () => selectedYearId,
);

final schoolClient = createSchoolClient(apiTransport);
final grants = await schoolClient.effectiveGrants();
final students = await schoolClient.students.list({'schoolId': grants.schoolId});
```

## Common commands

| Command | Description |
|---------|-------------|
| `melos run analyze` | Static analysis across all packages |
| `melos run test` | Run tests in all packages/apps |
| `melos run format` | Format Dart code |
| `melos list` | List workspace packages |

Run a single app:

```bash
cd apps/guardian && flutter run
cd apps/teacher && flutter run
```

Run package tests only:

```bash
melos exec --scope=edaya_api_client -- flutter test
melos exec --scope=edaya_auth -- flutter test
```
