# Teacher app — store release checklist

Use this checklist before submitting the teacher app to TestFlight / Play Console internal testing.

## Build and credentials

- [ ] Release build uses empty login form (no seeded credentials)
- [ ] API base URL override is not exposed in release UI
- [ ] `apps/teacher/web/manifest.json` description updated from placeholder
- [ ] App version and build number bumped in `pubspec.yaml`

## Security and privacy

- [ ] No student content or tokens in debug logs in release mode
- [ ] Push notification payloads do not log PII
- [ ] Offline outbox stores only operation payloads required for replay

## Reliability

- [ ] `flutter test` passes in `apps/teacher` and `packages/edaya_shared`
- [ ] Integration routes suite passes against seeded API (`teacher_routes_integration_test.dart`)
- [ ] Pending outbox rows visible on account screen and sync on reconnect
- [ ] Deep links resolve or fall back safely (`teacher_notification_targets_test.dart`)

## Accessibility

- [ ] Text scales to 200% without clipping on calendar, attendance, marks, and report-card flows
- [ ] Interactive tiles expose semantics labels (session, attendance, marks rows)
- [ ] French layouts reviewed on primary screens

## Tablet

- [ ] `NavigationRail` shell verified at ≥600dp width
- [ ] Marks entry grid layout verified at ≥600dp width

## Observability (pilot)

- [ ] Screen load timings emitted via `TeacherObservability`
- [ ] Outbox sync success/failure events emitted
- [ ] Deep-link failures logged when route loaders return errors

## Store assets

- [ ] Screenshots for phone and tablet (if applicable)
- [ ] Privacy policy URL configured
- [ ] Release notes drafted for pilot cohort
