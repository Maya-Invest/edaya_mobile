# Mobile portal integration tests

Live API tests in `tooling/integration_tests` exercise the same HTTP commands and entity reads that the teacher app controllers call. They catch backend auth regressions, missing seed data, and payload mismatches at the API boundary.

## What these tests cover

- Sign-in and portal bootstrap (`effectiveGrants`, assignments, academic years/periods, class groups)
- Calendar/timetable reads and enrichment
- Evaluations reads plus **write probes** (`createAssessment`, `recordAssessmentResult`)
- Session detail reads plus attendance write (subject teacher) / 403 (homeroom on subject lessons)
- Negative authorization probes (`staffMembers.get`)

Run:

```bash
melos run test:integration
```

## What these tests do not cover

Integration tests do **not** run Flutter controllers, widgets, or Levit task orchestration. Bugs in:

- optimistic UI updates after a save
- `runTask` / in-flight load races
- drawer/sheet navigation and local state refresh

belong in `apps/teacher/test/` (pure logic) or widget/controller tests. The evaluations persistence issue was an example: the API write probe passed while `loadMarks` could overwrite `saveMark` in the app layer.

When adding a new teacher feature API surface, add a matching integration probe **and** a focused unit test for any non-trivial client-side merge/invalidation logic.
