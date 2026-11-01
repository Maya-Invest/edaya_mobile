# Independent verification and releases

Each repository verifies and releases its own revision. Backend changes do not require synchronized consumer source changes, client package publication, or release manifests in sibling repositories. Cloudflare application deployments remain; no container publication is configured.

| Event | Required behavior |
| --- | --- |
| PR into `main` or `staging` | Full verification and integrations; no deployment |
| Other branch push | Repository checks and unit/tooling tests |
| Push to `staging` | Qualify that commit, release staging |
| Push to `main` | Qualify that commit, release production |
| Manual deployment | Select revision in the environment's deployment workflow; use the same qualification and deployment jobs |
| Manual validation | Select environment, revision, and optionally a backend reference; never deploy |

Deployments are serialized per repository/environment without cancelling active deployments. They depend on successful qualification; failure, cancellation or skipped qualification cannot deploy. Artifact restoration selects the unique qualified artifact from the same run and attempt, checks out its recorded source commit, restores frozen dependencies, and verifies file checksums. Deployment never resolves another backend branch or generates another client.

## Deployment prerequisites

Release workflows proceed automatically after successful qualification. Deployment retains its configured GitHub environment approvals and protections. No additional repository opt-in variable is required.

Deploy the backend tooling changes to the destination branches before consumers qualify against those branches: consumer integration uses the backend's typed fixture command. Configure branch protection to require **qualification / Full validation** from the PR workflow (confirm the exact displayed check name on the first rehearsal). Remove obsolete coordinator/publication checks only after that required check succeeds. GitHub may display the caller workflow name as an additional prefix.

Bun remains pinned to 1.3.14, Flutter to 3.44.8. Ubuntu CI and macOS development use native Git, archive tools and PostgreSQL binaries where needed. Validators are downloaded at pinned versions and verified against committed SHA-256 checksums. No first-party Python or Node operational runtime is required.

## Release evidence

`.ci-evidence/qualification.json` records source identity and mandatory outcomes. `.release/manifest.json` records source commit, environment, tool version, API fingerprint, artifact hashes and status. Consumer evidence includes backend commit and generated-client checksums. Evidence is an output; it does not pin another repository's future release. Private fixtures are disposable and logs are sanitized before they become retained evidence.

## Backend input

Production resolves backend `main`; staging resolves backend `staging`. Resolve once and detach at that SHA. A moving branch cannot change an existing checkout or generated client. The selected branch identifies the source tested, not necessarily the currently deployed backend.

Local preparation defaults to staging. `--ref <branch-or-commit>` is an explicit local override. `--backend-root <clean-checkout>` accepts an already resolved checkout. Ordinary CI selects only the destination branch; overrides are exposed by Manual validation. Integrations verify the backend checkout still equals the prepared client's commit and has no tracked edits before starting services.

`IDENTITY_CHECKOUT_TOKEN` needs read-only contents access to `Maya-Invest/edaya_backend`. It is used only for source checkout. Package-registry credentials and write permissions are no longer needed. Cache identities include backend SHA, generator/runtime inputs and relevant lockfiles; invalid checksum entries are rebuilt. Generated inputs are transferred with qualification artifacts and checked again before release.

## Mobile commands

```sh
flutter pub get
# The workspace includes tooling/repo.
dart run edaya_repo:repo generate client staging
flutter pub get --enforce-lockfile
dart run edaya_repo:repo check
dart run edaya_repo:repo ci verify
dart run edaya_repo:repo ci integration
```

Dart generates school and authentication contracts from the acquired backend's tracked OpenAPI definition into ignored `packages/edaya_api_client/lib/src/generated`. Handwritten runtime code, generator and generator test fixtures remain tracked. Generated binding metadata is in `.generated/client-bindings.json`. A clean checkout must run preparation before application analysis, tests or builds. Bun is needed only when running backend integration services/tools.

API, guardian and teacher integration suites are mandatory. Their machine-event gate rejects empty/incomplete discovery, missing or duplicate scenarios, skips, runner errors, stale results and unmapped routes. JSON output is sanitized. Run `dart run edaya_repo:repo ci validate-integration` to validate existing results without executing suites.

## Android releases

Use `dart run edaya_repo:repo build staging` for both signed APKs, or `build production` for both signed AABs. CI uses Java 17 and Flutter 3.44.8. Environment secret `ANDROID_SIGNING_BUNDLE` contains the existing keystore/apps bundle with guardian and teacher aliases/passwords and each Firebase configuration. Local builds can use existing private signing files. Missing credentials, debug certificates, app ID mismatches or signature verification errors block output.

Signed builds use the qualified source and transferred generated client. APK verification uses apksigner/aapt; AAB verification uses jarsigner/keytool, with signing certificate provenance and SHA-256 artifact hashes in `.release/manifest.json`. CI uploads those exact files; it does not submit to a store or add iOS delivery. Restored private signing files are cleaned up on failure and success.

Brand tokens, galleries, design review, keystore setup and SVG/native icon generation are Dart/Flutter commands under `generate` and `maintenance`. The asset generator runs through Flutter rendering; Node is no longer needed.

## Entrypoint migration inventory

| Previous entrypoints | Replacement or disposition |
| --- | --- |
| `generate-api-bindings.sh`, binding drift and mobile contract checks | Dart client acquisition/checks; ignored generated school/auth bindings |
| `integration-runner.py`, `staging-smoke.py`, their Python tests | `tooling/repo/lib/src/integration.dart`, `smoke.dart`, Dart tests |
| `brand-{tokens,check,gallery}.py`, Node `brand-assets.mjs` | Dart brand tools and Flutter SVG rendering |
| `build-staging-apks.sh`, `build-play-aab.sh`, APK signature/provenance scripts | Dart Android build/signature/artifact pipeline |
| `create-android-keystore.sh`, `dart-fix-package.sh`, `design-review.sh` | Explicit Dart maintenance commands |
| `ci_support.py`, shell service/lint launchers and workflow tests | Dart evidence/workflow tools, backend owned fixture and pinned actionlint |
| `release-contract.py`, committed generated binding snapshots | Removed; checksummed acquisition/release outputs |

Application analysis and tests run only after explicit client preparation. Flutter commands use frozen workspace dependencies (`--no-pub` after setup). Native Gradle/Flutter platform wrappers remain supported.

## Local migration rehearsal — 2026-10-11

A clean, isolated checkout acquired the tracked API definition from one immutable backend snapshot, generated the ignored Dart inputs, and passed application analysis, unit/widget tests and all integration suites: API **47/47**, guardian **43/43**, teacher **33/33**. The backend snapshot was local rehearsal source, not a claim about a deployed backend revision. The final tooling and retained generator also pass Dart analysis; all **18** tooling tests pass. Generator formatting changes were checked to preserve every generated-client checksum.

Both guardian and teacher staging APKs and production AABs were built locally with release signing. APK application identities, APK/AAB signatures, certificate fingerprints and output checksums were verified. Flutter asset rendering was exercised in a temporary output directory. No artifacts were published or submitted to stores.

The exact CI workspace setup command, `dart pub get --enforce-lockfile`, also passed with the pinned Flutter SDK. The evidence artifact retains sanitized machine-readable integration diagnostics as well as suite counts. GitHub-hosted qualification, artifact handoff and environment/signing-secret configuration were not established by this local rehearsal; configured environment approvals and protections still govern releases.
