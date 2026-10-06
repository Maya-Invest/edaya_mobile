# Live integration testing

`dart run melos run test:integration` runs the API, guardian and teacher suites independently and aggregates JSON outcomes. `dart run melos run test:integration:coverage` validates their current artifacts. CI gives each suite its own disposable stack and publishes only sanitized `.ci-evidence/results.json` even on failure. A failed child never prevents the other local suites from executing.

Feature/action contracts are in `tooling/integration_tests/features.json`; stable executable IDs are in `scenarios.json`. Route inventory tests walk the real registered GoRouter trees. Non-route actions and overlays must be registered explicitly. Update contract and assertions in the same feature PR. Reviewers verify behavioral meaning; an opened screen cannot prove a saved mutation.

The gate rejects empty discovery, duplicate IDs, missing or removed scenarios, unmapped routes, fixture failures, blocked tests, unexpected skips, machine-reported errors even with exit zero, incomplete streams and stale source fingerprints. Edit first, then rerun the complete suites. `python3 scripts/test_integration_runner.py` verifies these failure modes.

Live Flutter widget tests use production controllers, routes and real local HTTP services without a device or emulator. OTP is captured at the Identity delivery port; enrollment and verification still use the real identity application. The private mailbox, authenticator secrets and recovery codes must not be uploaded. The runner redacts JSON string values without corrupting machine events.

Mutable fixtures belong to their scenario. Reuse immutable school catalogs only. Dispose scopes, clear local session/settings state and reset outboxes between independent scenarios. Screenshot-generation suites remain separate from functional tests.

Coverage limits: actual WhatsApp/SMS/email delivery, push delivery, camera, native file opening, native secure storage and future support-assisted recovery require separate validation.

CI backend selection, credentials, required gates and evidence handling are described in [ci-setup.md](./ci-setup.md). All matrix jobs use one resolved backend SHA and matching release contracts.

`teacher.account.signature` draws a signature through the production editor, saves it using real private upload commands, verifies the teacher's stored attachment, replaces it with a new attachment and confirms removal. Unit/widget tests additionally cover alpha/proportions, rectangular cropping, invalid images, undo/clear/cancel, interrupted PUTs, failed completion/removal, receipt reuse and profile/sign-out races. Native gallery/camera selection and permission dialogs remain device validation; the editor and controller run in the Flutter test harness.
