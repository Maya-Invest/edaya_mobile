# Guardian and Teacher run and build variables

## Which API will the app use?

| How the app is built | Compiled API by default | Login API picker | Test OTP access |
|---|---|---|---|
| Local `flutter run` (debug) | Staging. Teacher on an iOS simulator uses `http://localhost:9999`. | Visible | Teacher opts in, Guardian opts out. Requires server support. |
| Manual `--profile` or `--release` with no defines | Staging for both apps | Hidden | Off |
| Manual `--release --dart-define=PRODUCTION=false` | Staging for both apps | Visible | Off |
| CI staging, including internal Play and TestFlight | `https://staging.api.edayaplus.com` | Visible | Off |
| CI production, including public Play and App Store | `https://api.edayaplus.com` | Hidden | Off |

**A manual release can be locked to staging.** `API_URL` chooses the default endpoint. `PRODUCTION` controls whether the app accepts runtime changes. With switching enabled, a saved URL takes priority over a nonempty `API_URL`, which takes priority over the app default. **Reset default** removes the saved choice. With switching disabled, authentication and school requests use the compiled endpoint even when an older installation saved a different URL. The account-screen picker also requires Flutter debug mode.

CI passes the same three defines on Android and iOS for a given target, including validation builds. Signing a staging release still produces a switchable app. [Dart build arguments](../../tooling/repo/lib/src/runtime.dart) · [iOS archive arguments](../../tooling/apple/release.rb) · [URL resolution](../../packages/edaya_shared/lib/src/config/api_base_url_config.dart)

## App compile-time defines

Pass these as `--dart-define=NAME=value` to `flutter run` or `flutter build` from either app directory. Changing a define requires a new run or build.

| Define | Applies to | Default | Effect |
|---|---|---|---|
| `PRODUCTION` | Both apps | `false` in debug, `true` in profile/release | `true` hides the picker and ignores runtime API overrides. Store CI sets it explicitly for each target. |
| `API_URL` | Both apps | Empty define uses the app default in the matrix above | Default base URL for both identity and school API calls. Local presets include `http://10.0.2.2:9999` for the Android emulator and `http://localhost:9999` for the iOS simulator. |
| `TEST_OTP_ACCESS` | Both apps | Debug Guardian off, debug Teacher on. Always off in profile/release. | In debug, an explicit boolean overrides the app default. If the server advertises testing access, Guardian offers reveal/copy and Teacher can fill an empty verification field. The explicit `false` in release commands repeats the build-mode guard. |
| `DEV_GUARDIAN_EMAIL` | Guardian | `m.kone@mail.ci` | Prefills the debug login identifier. Profile/release starts with an empty field. |
| `DEV_TEACHER_EMAIL` | Teacher | `a.toure@ecole-ci.edaya.dev` | Prefills the debug login identifier. Profile/release starts with an empty field. |
| `PROFILE_PHOTO_MAX_BYTES` | Both apps | `1048576` bytes (1 MiB) | Integer byte limit for client-side profile-photo encoding and crop validation. Both checked-in backend environments use 1 MiB, so the mobile store builds can use the default. |

The email prefills and OTP behavior follow Flutter build mode independently of the API lock. For example, a debug run with `PRODUCTION=true` can still prefill an email. Flutter supplies `dart.vm.product` and `dart.vm.profile` for mode detection. [Guardian config](../../apps/guardian/lib/config/api_config.dart) · [Guardian login route](../../apps/guardian/lib/app/router.dart) · [Teacher config](../../apps/teacher/lib/config/api_config.dart) · [OTP client](../../packages/edaya_auth/lib/src/auth_client.dart) · [Photo limit](../../packages/edaya_shared/lib/src/features/profile_photo/profile_photo_config.dart)

Run either example from `apps/guardian` or `apps/teacher`.

```sh
# Test a release-mode build and switch APIs on the device
flutter run --release --dart-define=PRODUCTION=false

# Reproduce the public-store API settings locally
flutter run --release --dart-define=PRODUCTION=true --dart-define=API_URL=https://api.edayaplus.com
```

## Build, signing and publication inputs

These inputs are read by the repository tools or GitHub Actions on the build host.

| Input | Source or default | Purpose |
|---|---|---|
| `target` / `TARGET` | CLI positional argument or workflow input, `staging` or `production`. Manual validation defaults to `staging`. | Selects the API, lock flag and release destination. Deployments from `staging` use staging, deployments from `main` use production. A PR validation build uses the target of its base branch. |
| `release_mode` / `RELEASE_MODE` | Reusable workflows default to `false`. Both deployment workflows set `true`. | Chooses distribution signing, artifact qualification and release handling. Both native validation and signed builds compile with Flutter `--release`. |
| `app` / `MOBILE_APP` | CI sets `guardian` or `teacher` per job. The build tools default to both when omitted. | Selects the app to build. For direct Flutter commands the working directory selects the app. |
| `source_ref`, `backend_ref` / `BACKEND_REF`, `match_backend_branch` / `MATCH_BRANCH` | Manual validation accepts optional revisions. Mobile defaults to the triggering SHA. Release backend defaults to `staging` or `main`. | Branch and PR checks enable branch matching, falling back to backend `dev` if the requested branch is absent. Locally, client generation accepts `--ref` or `--backend-root`. |
| `source_sha` / `CI_SOURCE_SHA`, `backend_sha` / `CI_BACKEND_SHA` | Resolved during preparation | Pin the mobile source, generated bindings and backend used by subsequent jobs. |
| `store_build` / `EDAYA_STORE_BUILD`, `reservation_attempt` | CI reserves the next shared `mobile-store-build/` tag and binds it to the workflow attempt. | Supplies the build number for both apps and platforms. Android adds the Play base. iOS encodes the counter as three numeric components. |
| `PLAY_VERSION_CODE_BASE` | GitHub repository variable, default `1000000` | Android version code is the base plus the reserved build. Local Android builds without CI numbering use the app's pubspec version. |
| `EDAYA_RELEASE_SEQUENCE`, `GITHUB_RUN_NUMBER`, `GITHUB_RUN_ATTEMPT` | Legacy fallback when the reserved counter is absent | The explicit sequence overrides the run number. Android uses `base + sequence × 100 + attempt` on this CI path. Apple uses its legacy three-part encoding. |
| `--build-name`, `--build-number` | Direct Flutter builds start from the app pubspec, currently `0.0.0+1` for both. The signed pipeline supplies `--build-number`. | Android consumes the Flutter version name/code. iOS reads `FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER` from generated build settings. |
| `ANDROID_HOME`, `ANDROID_SDK_ROOT` | Signed Android builder checks them in that order | Locate SDK build tools for APK verification. Gradle also reads `flutter.sdk` from the app's `android/local.properties`. |
| `ANDROID_SIGNING_BUNDLE` | GitHub Actions secret for signed Android jobs | Supplies the upload keystore, per-app signing properties and matching Firebase registrations. Local signed builds can use existing `key.properties` with `storeFile`, `keyAlias`, `storePassword` and `keyPassword`. |
| `EDAYA_KEYSTORE_STORE_PASSWORD`, `EDAYA_KEYSTORE_KEY_PASSWORD` | Optional for local keystore creation. The tool generates a store password by default, and the key password defaults to it. | Used when creating an upload keystore. The tool passes `STORE_PASSWORD`, `KEY_PASSWORD` and, during verification, `EDAYA_KEYSTORE_PASSWORD` to child processes. |
| `IOS_SIGNING_BUNDLE` | GitHub Actions secret for signed iOS jobs | Supplies the distribution certificate, its password and the two provisioning profiles. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` → `PLAY_ACCESS_TOKEN` | GitHub Actions secret → short-lived token | Google Play publication. The publisher receives the token for preparing and committing edits. |
| `APP_STORE_CONNECT_API_KEY_JSON` | GitHub Actions secret for Apple publication | Authenticates TestFlight uploads and App Review operations. |
| `BACKEND_CHECKOUT_TOKEN` | GitHub Actions secret for private backend checkout | Resolves the backend revision and reads the source used for client generation and integration fixtures. |

Sources and signing formats are in the [Android builder](../../tooling/repo/lib/src/android.dart), [Apple release tool](../../tooling/apple/release.rb), [manual validation workflow](../../.github/workflows/pr_validation.yml) and [CI setup](ci-setup.md).

### Workflow-managed variables

| Variables | Supplied value or role |
|---|---|
| `CI`, `GITHUB_ACTIONS`, `GITHUB_REF`, `GITHUB_REF_NAME`, `GITHUB_REPOSITORY`, `GITHUB_SHA`, `GITHUB_RUN_ID` | Runner identity, source revision, release branch and run evidence. `GH_TOKEN` is the workflow token used to reserve the store counter. |
| `GITHUB_OUTPUT`, `GITHUB_ENV`, `GITHUB_STEP_SUMMARY`, `RUNNER_TEMP` | Runner-provided paths for step outputs, downstream environment, summaries and temporary signing files. |
| `suite` / `SUITE`, `stage` / `STAGE`, `job_results` / `RESULTS` / `JOB_RESULTS` | The workflow selects a test suite, records stage evidence and checks all prerequisite job results. |
| `baseline_sha` / `COMPATIBILITY_BASE_SHA` | Candidate for removal from mobile CI. The PR workflow forwards its base revision to the fixture job. The job runs the mobile test suites, while the variable's reader belongs to the separate backend compatibility command. |
| `native-app` / `APP`, `seed`, `seed-flutter`, `platform`, `api-key` | Composite-action inputs select native plugin setup, Flutter cache writes, publication artifacts and the Apple API credential. |
| `DEVELOPER_DIR`, `BUNDLE_GEMFILE`, `FASTLANE_SKIP_UPDATE_CHECK`, `FASTLANE_OPT_OUT_USAGE` | iOS CI selects Xcode 26.1.1, points validation to the Apple Gemfile, and sets both Fastlane switches to `1`. |
| `GRADLE_OPTS`, `JAVA_TOOL_OPTIONS` | Android validation enables Gradle caching. The signing verifier sets the Java language/country to English/US for parsing tool output. |
| `GIT_TERMINAL_PROMPT`, `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_0`, `GIT_CONFIG_VALUE_0` | Backend branch lookup configures a noninteractive, authenticated Git subprocess for that command. |

The tracked workflow pins Flutter 3.44.8. Firebase project configuration and each app's store identifiers come from native/app configuration files. The API picker changes the identity and school HTTP endpoint. [Flutter setup](../../.github/actions/flutter/action.yml) · [Android workflow](../../.github/workflows/_build_android.yml) · [iOS workflow](../../.github/workflows/_build_ios.yml) · [Backend selection](../../tooling/repo/bin/backend_ref.dart)

## Local integration, smoke and design-review runs

| Host variable | Default or producer | Effect |
|---|---|---|
| `EDAYA_API_URL` / fallback `BASE_URL` | `http://localhost:9999` | API for integration tests. The staging smoke command requires the explicit staging URL. A Flutter app receives its endpoint through the separate `API_URL` Dart define. |
| `EDAYA_INTEGRATION_TESTS` / fallback `RUN_INTEGRATION_TESTS` | Off. The integration runner sets `1`. | `1` or `true` enables live test suites. |
| `EDAYA_TEACHER_EMAIL` / fallback `TEACHER_EMAIL` | `a.toure@ecole-ci.edaya.dev` | Sets the harness default email. The checked-in Teacher journeys replace it with the selected fixture profile's email before sign-in. An external harness could still use the default directly. |
| `EDAYA_ACADEMIC_YEAR_ID` / fallback `ACADEMIC_YEAR_ID` | `2025-ci` | Default year for school sessions. Named test profiles can supply their own year. |
| `EDAYA_CLASS_GROUP_ID` / fallback `CLASS_GROUP_ID` | `ci-6a` | Candidate for removal. The harness parses this field and a config test checks it. Current journeys select classes from fixture profiles and assignments. |
| `EDAYA_CALENDAR_REFERENCE_DATE`, `EDAYA_SCHOOL_ID` | `2026-09-17` and `sch-edaya-ci-cocody` | Reference day for calendar probes and school ID for fixture profile selection. |
| `BACKEND_ROOT`, `EDAYA_FIXTURE_SEED` | Mobile CI looks for `.ci/edaya_backend` and starts the backend fixture with seeding set to `true`. | Select the prepared backend checkout and populate the disposable integration environment. |
| `EDAYA_TEST_OTP_FILE`, `EDAYA_TEST_CLOCK_FILE`, `SEED_AUTH_SESSIONS_FILE` | Private fixture paths. Staging smoke requires a provisioned sessions file. | Local integration can read captured codes and control the test clock. Staging smoke requires capture and clock paths to be unset or empty and host `TEST_OTP_ACCESS` to be unset or `false`. |
| `EDAYA_STAGING_VALIDATE_ONLY`, `EDAYA_INTEGRATION_ARTIFACTS` | Set by the mobile runners | Select smoke-runner validation in CI or supply the output directory for integration failure diagnostics. |
| `EDAYA_DESIGN_REVIEW_LOCALE`, `EDAYA_DESIGN_REVIEW_THEME`, `EDAYA_DESIGN_REVIEW_TEXT_SCALE` | `fr`, `light`, `1` | Screenshot options are `fr/en`, `light/dark`, `1/2`. Both suites also accept locale as a Dart define. Teacher accepts theme and scale as Dart defines when host values are absent. |
| `EDAYA_DESIGN_REVIEW_A11Y`, `EDAYA_DESIGN_REVIEW_STRICT` | The maintenance command defaults both to `1`. | Produce accessibility evidence and fail strict review checks. |
| `EDAYA_MESSAGE_CAPTURES`, `EDAYA_BRAND_OUTPUT_ROOT` | Optional directories | Write message test captures or redirect generated brand assets. |
| `EDAYA_CI_API_PORT`, `EDAYA_CI_WEBAPP_ORIGIN`, `EDAYA_REVIEW_API_URL` | Teacher VS Code review task sets `19998`, `http://127.0.0.1:4173`, `http://127.0.0.1:19998` | Configure the local review fixture and seeder. The launch profile also passes the fixture endpoint as `API_URL` and sets `DEV_TEACHER_EMAIL=k.diomande@ecole-ci.edaya.dev`. |
| `EDAYA_CI_FILES_PORT` | The backend fixture picks a free local port by default. | Optional file-service port for a local integration run. It must differ from the fixture API port. |
| `FLUTTER_TEST` | Set by the Flutter test runner | Native push code skips Firebase messaging during tests unless a messaging override is supplied. |

Sources for local runs are the [integration config](../../tooling/integration_tests/lib/src/config/integration_config.dart), [smoke preflight](../../tooling/repo/lib/src/smoke.dart), [design-review command](../../tooling/repo/bin/repo.dart), [VS Code launch profile](../../.vscode/launch.json) and [fixture task](../../.vscode/tasks.json).
