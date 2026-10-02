# Live integration testing

`dart run melos run test:integration` runs the API, guardian and teacher suites independently and aggregates JSON outcomes. `dart run melos run test:integration:coverage` validates their current artifacts. CI gives each suite its own disposable stack and publishes `.integration-results` even on failure. A failed child never prevents the other local suites from executing.

Feature/action contracts are in `tooling/integration_tests/features.json`; stable executable IDs are in `scenarios.json`. Route inventory tests walk the real registered GoRouter trees. Non-route actions and overlays must be registered explicitly. Update contract and assertions in the same feature PR. Reviewers verify behavioral meaning; an opened screen cannot prove a saved mutation.

The gate rejects empty discovery, duplicate IDs, missing or removed scenarios, unmapped routes, fixture failures, blocked tests, unexpected skips, machine-reported errors even with exit zero, incomplete streams and stale source fingerprints. Edit first, then rerun the complete suites. `python3 scripts/test_integration_runner.py` verifies these failure modes.

Live Flutter widget tests use production controllers, routes and real local HTTP services without a device or emulator. OTP is captured at the Identity delivery port; enrollment and verification still use the real identity application. The private mailbox, authenticator secrets and recovery codes must not be uploaded. The runner redacts JSON string values without corrupting machine events.

Mutable fixtures belong to their scenario. Reuse immutable school catalogs only. Dispose scopes, clear local session/settings state and reset outboxes between independent scenarios. Screenshot-generation suites remain separate from functional tests.

Coverage limits: actual WhatsApp/SMS/email delivery, push delivery, camera, native file opening, native secure storage and future support-assisted recovery require separate validation.
