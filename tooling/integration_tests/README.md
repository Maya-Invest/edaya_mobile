# Mobile portal integration tests

Live API tests in `tooling/integration_tests` exercise the same HTTP commands and entity reads that the **teacher** and **guardian** app controllers call. They catch backend auth regressions, missing seed data, and payload mismatches at the API boundary.

## What these tests cover

### Teacher (`teacher_portal_integration_test.dart`)

- Sign-in and portal bootstrap (`effectiveGrants`, assignments, academic years/periods, class groups)
- Calendar/timetable reads and enrichment
- Evaluations reads plus **write probes** (`createAssessment`, `recordAssessmentResult`)
- Session detail reads plus attendance write (subject teacher) / 403 (homeroom on subject lessons)
- Negative authorization probes (`staffMembers.get`)

Demo accounts: `a.toure@ecole-ci.edaya.dev` (subject), `k.diomande@ecole-ci.edaya.dev` (homeroom).

### Guardian (`guardian_portal_integration_test.dart`)

- Sign-in and bootstrap (`effectiveGrants`, `guardianLinks`, linked students, enrollment, class group)
- Academic reads (periods, assessments, curriculum, **published report cards**)
- Fees reads (`getStudentFinanceSummary`, `studentCharges`, `getPaymentSettlementHistory`)
- Calendar/timetable + school events + student attendance list
- Inbox list + **`markDeliveryRead`** write probe, followed by a separate read to confirm persistence
- Negative authorization (`createAssessment`, `staffMembers.get`, `teachers.list`)

Demo accounts: `m.kone@mail.ci` (children `ci-s1` + `ci-s10`), `k.yao@mail.ci` (`ci-s4`, `ci-s7`, `ci-s8`).

Each inbox probe uses the seeded owner (`a.kone@ecole-ci.edaya.dev`) to create and publish a unique announcement targeted to that guardian. It waits for the notification workflow to materialize an unread delivery, then reads and marks it as the guardian. The director fixture has class-scoped send grants and cannot address direct recipients; delivery-history writes remain system-only. Run these write probes against disposable seeded data with local-log notification delivery.

Run:

```bash
melos run test:integration
```

Optional env overrides:

```bash
EDAYA_GUARDIAN_EMAIL=m.kone@mail.ci \
EDAYA_ACADEMIC_YEAR_ID=2025-ci \
melos run test:integration
```

Identity must have `AUTH_DEV_OTP_PEEK=true` so tests can read the emailed code.

## What these tests do not cover

API integration tests do **not** run Flutter controllers, widgets, or Levit task orchestration. Bugs in:

- optimistic UI updates after a save
- `runTask` / in-flight load races
- drawer/sheet navigation and local state refresh

belong in `apps/teacher/test/` or `apps/guardian/test/` (pure logic) or widget/controller tests.

### Guardian widget integration tests

Live API widget tests live in `apps/guardian/test/integration/`. They reuse this package's harness (`PortalSession`, `bootstrapGuardianPortal`, feature probes) and pump real guardian pages under `flutter test`.

Coverage includes the app shell (all five tabs), calendar timetable and events views, session details, student switching, academic curriculum progress, evaluations grades and report cards, fees and payment details, inbox message details, and attendance list views.

Demo accounts: `m.kone@mail.ci` (children `ci-s1` + `ci-s10`), `k.yao@mail.ci` (`ci-s4`, `ci-s7`, `ci-s8`).

### Teacher widget integration tests

Live API widget tests live in `apps/teacher/test/integration/`. They reuse `PortalSession`, `bootstrapTeacherPortal`, and feature probes, then pump real teacher pages under `flutter test`.

Coverage includes Accueil, agenda, classes, evaluations, inbox, account/settings, and live session routes.

Run with the rest of the integration suite:

```bash
melos run test:integration
```

Or only guardian widget integration tests:

```bash
cd apps/guardian && EDAYA_INTEGRATION_TESTS=1 flutter test --tags integration
```

Or only teacher widget integration tests:

```bash
cd apps/teacher && EDAYA_INTEGRATION_TESTS=1 flutter test test/integration --tags integration
```

Unit/widget runs (`melos run test`) exclude `@Tags(['integration'])` tests so CI verify does not require a running API.

When adding a new portal feature API surface, add a matching integration probe **and** a focused unit test for any non-trivial client-side merge/invalidation logic. When the feature has meaningful UI, add a guardian or teacher widget integration test that asserts the page renders seeded API data. A second guardian profile locks linked-student scope only. Page mounts belong to smoke, not a live route file.

Widget boot tests are not required when smoke already covers that screen. Keep a unit test when it locks a branch the integration probe cannot see (parse/reject, offline conflict, deeplink). A constant or boolean gate already covered by a nearby auth or client test does not need its own file.
