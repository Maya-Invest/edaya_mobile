# Independent verification and releases

Each repository verifies and releases its own revision. Backend changes do not require synchronized consumer source changes, client package publication, or release manifests in sibling repositories. Cloudflare application deployments remain; no container publication is configured.

| Entry point | Trigger | Stages |
| --- | --- | --- |
| `branch_check.yml` | Push outside staging/main | Prepare once, then quality and unit in parallel |
| `pr_validation.yml` | PR into staging/main or manual validation | Prepare → quality, unit and four independent builds (Guardian and Teacher on Android and iOS). API, Guardian and Teacher integration jobs run in parallel after quality and unit. **Full validation** requires all ten upstream jobs. |
| `deploy_testing.yml` | Push or manual dispatch on `staging` | Fully qualify and sign both apps with the staging API, then deploy to Play internal testing and TestFlight |
| `deploy_live.yml` | Push or manual dispatch on `main` | Fully qualify and sign both apps with the production API, then submit to Google Play production and Apple App Review |

For branch pushes and PRs, prepare uses a matching backend branch (PR head branch), falling back to backend `dev` only if that branch is absent. PRs validate the proposed merge commit. Manual validation allows explicit revisions. Releases use the selected branch SHA and its matching backend destination. Manual release accepts no revision override.

All stages restore the frozen client and lockfile for the same run and attempt. Signing credentials are passed to release build jobs only. Finalization checks source, backend, target, job results and artifact checksums. The publishers restore the qualified binaries, verify their checksums and submit them without rebuilding. Re-run all jobs to qualify a new attempt. Each publisher downloads its own app/platform artifact. Both Play edits must pass before either commit. Production App Review submissions wait for both TestFlight uploads and eligibility checks. Staging and production deployments share a queue because their Play edits target the same packages.

Linux preparation and the Guardian macOS release build seed the pinned Flutter SDK and lockfile-keyed Pub cache on release branches. PRs can restore their base branch caches. Android reuses Gradle User Home and enables task-output caching for validation builds. iOS reuses each app's Swift package downloads keyed by the Flutter SDK, Xcode build, app package pins and Pub lock. Signed binaries and qualification evidence are transferred as same-attempt artifacts.

## Remaining configuration for Guardian v2 and Teacher v2

Staging successfully produced both signed Android APKs on November 14, 2026. [Staging run](https://github.com/Maya-Invest/edaya_mobile/actions/runs/43574671877)

### Branches and credentials

| Branch | Backend source and compiled API | Store destination for both apps |
| --- | --- | --- |
| `staging` | Backend `staging`, `https://staging.api.edayaplus.com` | Google Play internal testing and internal TestFlight. Signed Android APKs are also available as artifacts. |
| `main` | Backend `main`, `https://api.edayaplus.com` | Fresh production builds sent to Google Play production review and Apple App Review. |

Production qualification requires the integration fixture command in backend `main`. The backend maintainer must land the fixture tooling there before the first production qualification. Merging into mobile `main` starts the production workflow. Both entry points call `_release.yml`. Preparation allocates one store build number under their shared release queue and freezes it in the current attempt’s prepared artifact. A rerun uses a new number and must still target the branch tip.

| Actions secret | Purpose |
| --- | --- |
| `BACKEND_CHECKOUT_TOKEN` | Read backend contents for qualification. Configured at repository scope. |
| `ANDROID_SIGNING_BUNDLE` | Upload keys, signing properties and matching Firebase configuration for both Android apps. Configured. |
| `IOS_SIGNING_BUNDLE` | Distribution certificate, password and both App Store profiles. Configured. |
| `APP_STORE_CONNECT_API_KEY_JSON` | Team key for both apps. Configured. Production review requires App Manager access. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Full Google service-account key for both apps. Still required as of November 14, 2026. |

Repository secrets apply to both release jobs. Where environment secrets are available, configure testing credentials in `staging` and public-release credentials in `production`. Restrict production to `main` where supported. With a shared Play account, grant it both testing and production release permissions. The optional repository variable `PLAY_VERSION_CODE_BASE` defaults to `1000000` and must be consistent across branches. Store builds ignore saved developer endpoint overrides. [Actions secrets](https://github.com/Maya-Invest/edaya_mobile/settings/secrets/actions)

### Upload the signing bundles

Use a terminal on the Mac holding your existing signing keys. Run these commands from the mobile repository root. The two packers below write compact JSON to a private temporary directory. You can skip the packers if you already have the two JSON bundles in a private directory.

```sh
export EDAYA_SIGNING_DIR="$(mktemp -d)"
```

**Android.** Use the existing Play upload keystore, the signing properties for each alias, and the two v2 Firebase registrations.

```sh
python3 - <<'PY'
import base64, json, os
from pathlib import Path

os.umask(0o077)
keystore = Path("android-signing/edaya-upload.jks").resolve()
apps = {}
for app in ("guardian", "teacher"):
    android = Path(f"apps/{app}/android")
    props_file = android / "key.properties"
    props = dict(line.split("=", 1) for line in props_file.read_text().splitlines()
                 if "=" in line and not line.startswith("#"))
    if (props_file.parent / props["storeFile"]).resolve() != keystore:
        raise SystemExit(f"Check the upload keystore path in {props_file}")
    apps[app] = {key: props[key] for key in ("keyAlias", "keyPassword", "storePassword")}
    apps[app]["firebase"] = json.loads((android / "app/google-services.json").read_text())
bundle = {"keystore": base64.b64encode(keystore.read_bytes()).decode("ascii"), "apps": apps}
with (Path(os.environ["EDAYA_SIGNING_DIR"]) / "android.json").open("x") as out:
    json.dump(bundle, out, separators=(",", ":"))
PY
```

**Apple.** In Keychain Access, export the Apple Distribution identity including its private key as a password-protected `.p12`. Download the two App Store distribution profiles issued for that certificate and team `SQFU4GGCX2`. Replace the three example paths below. The password prompt reads from the terminal with echo disabled. [Apple signing requirements](apple-releases.md#credentials)

```sh
python3 - /path/to/distribution.p12 /path/to/guardian.mobileprovision /path/to/teacher.mobileprovision <<'PY'
import base64, getpass, json, os, sys
from pathlib import Path

os.umask(0o077)
cert, guardian, teacher = (base64.b64encode(Path(p).read_bytes()).decode("ascii") for p in sys.argv[1:])
bundle = {"certificate": cert, "password": getpass.getpass("P12 export password: "),
          "profiles": {"guardian": guardian, "teacher": teacher}}
with (Path(os.environ["EDAYA_SIGNING_DIR"]) / "ios.json").open("x") as out:
    json.dump(bundle, out, separators=(",", ":"))
PY
```

**Upload on the current Free plan.** Repository-level Actions secrets can hold both signing bundles. The release caller explicitly passes the signing secrets to their platform build jobs. This makes each value available to eligible workflows across this repository. It also means both Android environments use the same signing bundle. The two stores also require their publishing credentials. Each JSON payload must fit GitHub's 48 KB secret limit. The CLI reads from standard input and encrypts before sending. [GitHub secret limits](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#storing-large-secrets) · [GitHub CLI](https://cli.github.com/manual/gh_secret_set)

```sh
gh secret set ANDROID_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile < "$EDAYA_SIGNING_DIR/android.json"
gh secret set IOS_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile < "$EDAYA_SIGNING_DIR/ios.json"
gh secret list --repo Maya-Invest/edaya_mobile
```

For environment-scoped signing on a supported plan, create `staging` and `production` in repository Settings → Environments. Use the commands below instead. Run `gh secret list --repo Maya-Invest/edaya_mobile --env production` (and likewise for `staging`) to verify the names.

```sh
gh secret set ANDROID_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile --env staging < "$EDAYA_SIGNING_DIR/android.json"
gh secret set ANDROID_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile --env production < "$EDAYA_SIGNING_DIR/android.json"
gh secret set IOS_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile --env staging < "$EDAYA_SIGNING_DIR/ios.json"
gh secret set IOS_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile --env production < "$EDAYA_SIGNING_DIR/ios.json"
```

If you created the temporary directory above, remove its generated `android.json` and `ios.json` after confirming the uploads. Keep the original keystore, certificate, profiles and passwords in your credential backup.

### Store and app-owner checks

Store accounts, highest uploaded versions and production push delivery still need confirmation by the respective account owners. The app identities used by the workflows are:

| App | Google Play package | App Store bundle ID |
| --- | --- | --- |
| Guardian v2 | `ca.mayainvest.edaya.guardian` | `ca.maya-invest.edaya.guardian` |
| Teacher v2 | `ca.mayainvest.edaya.teacher` | `ca.maya-invest.edaya.teacher` |

| When | Owner | Configure or verify |
| --- | --- | --- |
| Before Google Play internal testing | Google Cloud and Play admins | Enable the Android Publisher and IAM Service Account Credentials APIs. Grant each service account Token Creator on itself for the workflow's access-token flow. In Play Console, grant both accounts view access to both apps, the publisher testing-track release access, and the promoter production release access. Confirm both apps have Play App Signing, the matching upload certificates, initial AABs accepted, an internal tester list and opt-in links. Compare existing codes before choosing the base. [Google Play setup and exact signing JSON](google-play-releases.md) |
| Before TestFlight | Apple Developer and App Store Connect admins | For team `SQFU4GGCX2`, confirm both explicit identifiers, enable Push Notifications on both and Associated Domains on Guardian, issue App Store profiles covering the supplied certificate, and confirm both app records and API keys. Set up an internal group with automatic distribution for each app, add testers, and clear applicable export-compliance prompts. Both v2 pubspecs currently select `1.0.0`. Check each app's version and build history before the first upload. [Apple setup and exact signing JSON](apple-releases.md) · [Apple internal testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/) |
| Before testing push and invitation links | Firebase and web admins | Confirm that the Firebase project `edayaplus` has production APNs credentials for both iOS registrations. For Guardian, verify the public association files on the invitation hosts serve the v2 Apple application identifier and the Play **app signing** certificate fingerprint. The public file checks from this audit were inconclusive. Validate on store-installed builds. [Apple push setup](apple-push-notifications.md) |
| Before public release | Store release owners | Complete the applicable listing, privacy, policy, country availability and review information for both apps. Merge the tested source into `main` when ready to submit production builds. Release approved Apple builds manually and use Play Console managed publishing to control eligible Google Play updates. [Google Play](google-play-releases.md) · [Apple](apple-releases.md) |

## Deployment prerequisites

Release workflows proceed automatically after successful qualification. Deployment retains its configured GitHub environment approvals and protections. No additional repository opt-in variable is required.

Deploy the backend tooling changes to the destination branches before consumers qualify against those branches: consumer integration uses the backend's typed fixture command. Configure branch protection to require **qualification / Full validation** from the PR workflow (confirm the exact displayed check name on the first rehearsal). Remove obsolete coordinator/publication checks only after that required check succeeds. GitHub may display the caller workflow name as an additional prefix.

Bun remains pinned to 1.3.14, Flutter to 3.44.8. Ubuntu CI and macOS development use native Git, archive tools and PostgreSQL binaries where needed. Validators are downloaded at pinned versions and verified against committed SHA-256 checksums. Dart owns the main repository operations. Fastlane handles Apple signing and store delivery.

## Release evidence

`.ci-evidence/qualification.json` records source identity and mandatory outcomes. `.release/<app>/manifest.json` records source commit, environment, tool version, API fingerprint, artifact hashes and status. Consumer evidence includes backend commit and generated-client checksums. Evidence is an output; it does not pin another repository's future release. Private fixtures are disposable and logs are sanitized before they become retained evidence.

## Backend input

Production resolves backend `main`; staging resolves backend `staging`. Resolve once and detach at that SHA. A moving branch cannot change an existing checkout or generated client. The selected branch identifies the source tested, not necessarily the currently deployed backend.

Local preparation defaults to staging. `--ref <branch-or-commit>` is an explicit local override. `--backend-root <clean-checkout>` accepts an already resolved checkout. Release CI selects the destination branch. Branch checks and PRs match the feature branch, with a fallback to dev. Manual validation accepts an explicit override. Integrations verify the backend checkout still equals the prepared client's commit and has no tracked edits before starting services.

`BACKEND_CHECKOUT_TOKEN` needs read-only contents access to `Maya-Invest/edaya_backend`. It is used only for source checkout. Package-registry credentials and write permissions are no longer needed. Cache identities include backend SHA, generator/runtime inputs and relevant lockfiles; invalid checksum entries are rebuilt. Generated inputs are transferred with qualification artifacts and checked again before release.

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

The `api`, `guardian_v2` and `teacher_v2` integration suites are mandatory. Their machine-event gate rejects empty/incomplete discovery, missing or duplicate scenarios, skips, runner errors, stale results and unmapped routes. JSON output is sanitized. Run `dart run edaya_repo:repo ci validate-integration` to validate existing results without executing suites.

## Android releases

Use `dart run edaya_repo:repo build staging` for both apps' signed APKs and AABs, or `build production` for both signed v2 AABs. Release paths are `apps/guardian` and `apps/teacher`; logical app keys remain `guardian` and `teacher`. CI uses Java 17 and Flutter 3.44.8. Environment secret `ANDROID_SIGNING_BUNDLE` contains the existing keystore/apps bundle with guardian and teacher aliases/passwords and each Firebase configuration. Local builds can use existing private signing files. Missing credentials, debug certificates, app ID mismatches or signature verification errors block output.

Signed builds use the pinned source and transferred generated client. APK verification uses apksigner/aapt; AAB verification uses jarsigner/keytool, with signing certificate provenance and SHA-256 artifact hashes in `.release/<app>/manifest.json` on CI. Both release branches publish their qualified AABs to the matching Play track. Restored private signing files are cleaned up after the build. Apple build and publishing jobs exchange the signed IPAs verified by finalization. [Google Play releases](google-play-releases.md) · [Apple releases](apple-releases.md)

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

Application analysis and tests run after client preparation. CI installs dependencies with `--enforce-lockfile` and checks the prepared lockfile again when recording each build. Android release builds let Flutter regenerate the plugin list in release mode so it excludes development-only plugins such as `integration_test`. Native Gradle/Flutter platform wrappers remain supported.

## Local migration rehearsal — 2026-10-11

A clean, isolated checkout acquired the tracked API definition from one immutable backend snapshot, generated the ignored Dart inputs, and passed application analysis, unit/widget tests and all integration suites: API **47/47**, guardian **43/43**, teacher **33/33**. The backend snapshot was local rehearsal source, not a claim about a deployed backend revision. The final tooling and retained generator also pass Dart analysis; all **18** tooling tests pass. Generator formatting changes were checked to preserve every generated-client checksum.

Both guardian and teacher staging APKs and production AABs were built locally with release signing. APK application identities, APK/AAB signatures, certificate fingerprints and output checksums were verified. Flutter asset rendering was exercised in a temporary output directory. No artifacts were published or submitted to stores.

The exact CI workspace setup command, `dart pub get --enforce-lockfile`, also passed with the pinned Flutter SDK. The evidence artifact retains sanitized machine-readable integration diagnostics as well as suite counts. GitHub-hosted qualification, artifact handoff and environment/signing-secret configuration were not established by this local rehearsal; configured environment approvals and protections still govern releases.
