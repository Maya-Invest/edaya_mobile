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
- Fees reads (`studentFees`, `payments`, `fees.get`)
- Calendar/timetable + school events + student attendance list
- Inbox list + **`markDeliveryRead`** write probe (staff seeds a fresh unread delivery per test)
- Negative authorization (`createAssessment`, `staffMembers.get`, `teachers.list`)

Demo accounts: `m.kone@mail.ci` (children `ci-s1` + `ci-s10`), `k.yao@mail.ci` (`ci-s4`, `ci-s7`, `ci-s8`).

Run:

```bash
melos run test:integration
```

Optional env overrides:

```bash
EDAYA_GUARDIAN_EMAIL=m.kone@mail.ci \
EDAYA_GUARDIAN_PASSWORD=DevPassword1! \
EDAYA_ACADEMIC_YEAR_ID=2025-ci \
melos run test:integration
```

## What these tests do not cover

API integration tests do **not** run Flutter controllers, widgets, or Levit task orchestration. Bugs in:

- optimistic UI updates after a save
- `runTask` / in-flight load races
- drawer/sheet navigation and local state refresh

belong in `apps/teacher/test/` or `apps/guardian/test/` (pure logic) or widget/controller tests.

### Guardian widget integration tests

Live API widget tests live in `apps/guardian/test/integration/`. They reuse this package's harness (`PortalSession`, `bootstrapGuardianPortal`, feature probes) and pump real guardian pages under `flutter test`.

Coverage includes the app shell (bottom navigation), calendar, academic, evaluations, fees, inbox, and attendance list views.

Run with the rest of the integration suite:

```bash
melos run test:integration
```

Or only guardian widget integration tests:

```bash
cd apps/guardian && EDAYA_INTEGRATION_TESTS=1 flutter test --tags integration
```

Unit/widget runs (`melos run test`) exclude `@Tags(['integration'])` tests so CI verify does not require a running API.

When adding a new portal feature API surface, add a matching integration probe **and** a focused unit test for any non-trivial client-side merge/invalidation logic. When the feature has meaningful UI, add a guardian widget integration test that asserts the page renders seeded API data.
