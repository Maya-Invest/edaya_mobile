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

## Remaining configuration for Guardian v2 and Teacher v2

**GitHub audit, 2026-11-13.** Actions is enabled and the required third-party actions are allowed. GitHub confirms that the repository secret `BACKEND_CHECKOUT_TOKEN` exists. An earlier branch check stopped at **Checkout backend input** with a missing token. Its read access to the backend can be verified by a new run using the updated workflow. [Earlier failed run](https://github.com/Maya-Invest/edaya_mobile/actions/runs/43547554414)

### GitHub and backend prerequisites

| Owner | Observed state | Remaining work |
| --- | --- | --- |
| Mobile repository admin | The mobile qualification workflow uses the configured `BACKEND_CHECKOUT_TOKEN` repository secret. | After the workflow rename reaches GitHub, verify the **Checkout backend input** step on the next branch run. Full integration runs on a PR targeting `staging` or `main`. |
| Organization owner | Maya-Invest reports the Free plan. Private organization repositories need Team or Enterprise for environment secrets. | For the workflows as written, enable a plan supporting private environments and create the four environments below. Staying on Free requires a workflow change to use a different credential arrangement. Manual dispatch already provides the production release decision. GitHub required environment reviewers for a private repository require Enterprise. [GitHub environment availability](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments) |
| Backend maintainer | Both backend branches have `tooling/repo/fixtures/openapi.json`. Backend `staging` has the integration fixture tooling. Backend `main` at `ca02b7e` lacks `tooling/repo/ops/main.ts`. | Land the backend tooling that implements `ci fixture` and its dependencies on backend `main` before production qualification. |
| Mobile maintainer | The release workflows are on `optim/pre-release` at `4794140`. Mobile `staging` has older checks. The default branch, `main`, has no workflow directory. | Land the v2 source, tooling and workflows on `staging` for the signed APK rehearsal. Land them on `main` after preparing both stores, since a push starts production qualification and beta delivery. GitHub exposes manual workflow dispatch after the workflow reaches the default branch. [GitHub manual dispatch](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow) |
| Mobile repository admin | GitHub reports `main` and `staging` are unprotected. | Once available on the chosen plan and visible on a PR, require the PR's **qualification / Full validation** check. Scope the two public-release environments to `main`. Optional environment reviewers are a separate control. |

### Credential and variable inventory

As of 2026-11-14, `BACKEND_CHECKOUT_TOKEN`, `ANDROID_SIGNING_BUNDLE`, `IOS_SIGNING_BUNDLE` and `APP_STORE_CONNECT_API_KEY_JSON` are configured as repository Actions secrets. The four release environments are absent. The table shows the intended scopes when configuring environment-specific credentials. [Actions secrets](https://github.com/Maya-Invest/edaya_mobile/settings/secrets/actions) · [Environments](https://github.com/Maya-Invest/edaya_mobile/settings/environments)

| Scope | Secret | Value and purpose |
| --- | --- | --- |
| Repository | `BACKEND_CHECKOUT_TOKEN` | A token with Contents: read on `Maya-Invest/edaya_backend` for branch checks, PRs and release qualification. A fine-grained PAT scoped to that backend repository is one option. |
| `staging` | `ANDROID_SIGNING_BUNDLE` | Existing upload JKS, both aliases and passwords, and each v2 app's matching Firebase Android configuration. Signs both staging APKs. |
| `production` | `ANDROID_SIGNING_BUNDLE` | The same signing bundle format with the upload keys registered in Play Console. Signs both production AABs. |
| `production` | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | JSON key for the service account that can publish both apps to testing tracks. |
| `production` | `IOS_SIGNING_BUNDLE` | Base64 Apple Distribution `.p12` containing the private key, its password, and base64 App Store provisioning profiles for Guardian and Teacher. |
| `production` | `APP_STORE_CONNECT_API_KEY_JSON` | Team API key with Developer access for TestFlight upload. JSON fields are `key_id`, `issuer_id` and `key` (the full `.p8` text). |
| `google-play-production` | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | JSON key for a separate promoter account with read access and the production release permission for both apps. |
| `app-store-production` | `APP_STORE_CONNECT_API_KEY_JSON` | Team API key with App Manager access for App Review submission. |

The only operator-set Actions variable is optional. In `production`, set `PLAY_VERSION_CODE_BASE` only if needed so `base + 100 × run_number + run_attempt` exceeds the highest uploaded code across both Play apps. The base defaults to `1000000`. GitHub supplies `GITHUB_TOKEN` and the run identifiers. The release workflows set the Flutter, Java, Ruby, Bun and Xcode versions, API endpoints and OTP settings. Staging APKs default to `https://staging.api.edayaplus.com`. Google Play internal and TestFlight builds default to `https://api.edayaplus.com`. Both apps honor a previously saved API URL override.

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

**Upload on the current Free plan.** Repository-level Actions secrets can hold both signing bundles. The deployment callers use `secrets: inherit`, and the signing jobs reference the names below. This makes each value available to eligible workflows across this repository. It also means both Android environments use the same signing bundle. The separate credentials for beta publishing and public promotion still need their own configuration. Each JSON payload must fit GitHub's 48 KB secret limit. The CLI reads from standard input and encrypts before sending. [GitHub secret limits](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#storing-large-secrets) · [GitHub CLI](https://cli.github.com/manual/gh_secret_set)

```sh
gh secret set ANDROID_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile < "$EDAYA_SIGNING_DIR/android.json"
gh secret set IOS_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile < "$EDAYA_SIGNING_DIR/ios.json"
gh secret list --repo Maya-Invest/edaya_mobile
```

For environment-scoped signing on a supported plan, create `staging` and `production` in repository Settings → Environments. Use the commands below instead. Run `gh secret list --repo Maya-Invest/edaya_mobile --env production` (and likewise for `staging`) to verify the names.

```sh
gh secret set ANDROID_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile --env staging < "$EDAYA_SIGNING_DIR/android.json"
gh secret set ANDROID_SIGNING_BUNDLE --repo Maya-Invest/edaya_mobile --env production < "$EDAYA_SIGNING_DIR/android.json"
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
| Before public release | Store release owners | Complete the applicable listing, privacy, policy, country availability and review information for both apps. Record the tested Guardian and Teacher Play version codes and the two tested iOS marketing-version/build pairs. On `main`, **Promote Google Play to production** requests 100% rollout of those codes. **Submit TestFlight builds to App Store** submits the selected builds for review. Its default leaves public release to the operator after approval. [Play promotion](google-play-releases.md) · [App Store submission](apple-releases.md) |

The first end-to-end proof is a successful staging deployment with two signed APKs, followed by a qualified production run with both Play internal releases available to testers and both TestFlight builds processed and installable. Public promotion is a separate operator decision.

## Deployment prerequisites

Release workflows proceed automatically after successful qualification. Deployment retains its configured GitHub environment approvals and protections. No additional repository opt-in variable is required.

Deploy the backend tooling changes to the destination branches before consumers qualify against those branches: consumer integration uses the backend's typed fixture command. Configure branch protection to require **qualification / Full validation** from the PR workflow (confirm the exact displayed check name on the first rehearsal). Remove obsolete coordinator/publication checks only after that required check succeeds. GitHub may display the caller workflow name as an additional prefix.

Bun remains pinned to 1.3.14, Flutter to 3.44.8. Ubuntu CI and macOS development use native Git, archive tools and PostgreSQL binaries where needed. Validators are downloaded at pinned versions and verified against committed SHA-256 checksums. Dart owns the main repository operations. Fastlane handles Apple signing and store delivery.

## Release evidence

`.ci-evidence/qualification.json` records source identity and mandatory outcomes. `.release/manifest.json` records source commit, environment, tool version, API fingerprint, artifact hashes and status. Consumer evidence includes backend commit and generated-client checksums. Evidence is an output; it does not pin another repository's future release. Private fixtures are disposable and logs are sanitized before they become retained evidence.

## Backend input

Production resolves backend `main`; staging resolves backend `staging`. Resolve once and detach at that SHA. A moving branch cannot change an existing checkout or generated client. The selected branch identifies the source tested, not necessarily the currently deployed backend.

Local preparation defaults to staging. `--ref <branch-or-commit>` is an explicit local override. `--backend-root <clean-checkout>` accepts an already resolved checkout. Ordinary CI selects only the destination branch; overrides are exposed by Manual validation. Integrations verify the backend checkout still equals the prepared client's commit and has no tracked edits before starting services.

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

Use `dart run edaya_repo:repo build staging` for both signed v2 APKs, or `build production` for both signed v2 AABs. Release paths are `apps/guardian` and `apps/teacher`; logical app keys remain `guardian` and `teacher`. CI uses Java 17 and Flutter 3.44.8. Environment secret `ANDROID_SIGNING_BUNDLE` contains the existing keystore/apps bundle with guardian and teacher aliases/passwords and each Firebase configuration. Local builds can use existing private signing files. Missing credentials, debug certificates, app ID mismatches or signature verification errors block output.

Signed builds use the qualified source and transferred generated client. APK verification uses apksigner/aapt; AAB verification uses jarsigner/keytool, with signing certificate provenance and SHA-256 artifact hashes in `.release/manifest.json`. Production deployments publish those exact qualified AABs for Guardian and Teacher to Google Play **internal testing**. Staging remains APK artifact delivery. Restored private signing files are cleaned up on failure and success.

Google Play production promotion is a separate manual workflow, **Promote Google Play to production**, run from `main` with explicit Guardian and Teacher version codes. It uses the `google-play-production` GitHub environment and promotes already-tested bundles without rebuilding. See [Google Play releases](google-play-releases.md) for credentials, first-release setup, version codes, and recovery. Production also runs a macOS job that builds signed v2 IPAs from the same qualified inputs and uploads them to TestFlight. App Store review submission is a separate manual workflow. See [Apple releases](apple-releases.md).

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
