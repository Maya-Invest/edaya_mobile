# Apple releases

Both stores now publish the v2 workspaces. Android keeps its existing package IDs and upload keys. Apple uses these existing v2 registrations:

| App key | Workspace | iOS bundle ID | Apple team |
| --- | --- | --- | --- |
| `guardian` | `apps/guardian` | `ca.maya-invest.edaya.guardian` | `SQFU4GGCX2` |
| `teacher` | `apps/teacher` | `ca.maya-invest.edaya.teacher` | `SQFU4GGCX2` |

`tooling/apple/apps.json` is the Apple release configuration. Each app key maps to its workspace and selects its signing profile. iOS bundle IDs intentionally differ from Android IDs.

## Pipeline

On a push to `main`, **Deploy production** first runs qualification on Linux, including all integration suites and the Apple release-tooling tests. Its Android and Apple release jobs then run independently from the same qualification artifact. A failure on one platform cannot undo an upload already completed on the other.

Both apps use Swift Package Manager for native Flutter plugins. The Apple job runs on `macos-15` with Xcode **26.1.1**, Flutter **3.44.8**, Ruby **3.3**, and locked Fastlane dependencies. It restores the exact qualified revision, generated client and Dart lockfile; revalidates their evidence; creates a temporary signing keychain; installs the supplied distribution profiles; builds both production IPAs; verifies signing, identity, team, build number and production APNs entitlement; then uploads both IPAs to App Store Connect/TestFlight. It uses the production API URL and disables test OTP access.

Signing certificates, profiles and passwords never enter release artifacts. Temporary profiles and the keychain are removed and project settings restored on normal completion or errors. Jobs use disposable GitHub-hosted runners; forced runner termination also discards the runner's storage. Do not run this workflow on persistent self-hosted machines without an additional cancellation cleanup policy.

TestFlight uploads return before Apple finishes processing. Configure an **internal TestFlight group with automatic distribution** for each app in App Store Connect, add testers, and complete any encryption/export-compliance questions. The workflow does not create testers or submit external beta review. Check that processing succeeded and install/test both versions before requesting production submission.

Staging continues producing Android APK artifacts; it does not upload staging-backend builds to TestFlight. PRs verify the release tooling but do not sign or upload iOS builds.

## Credentials

GitHub has `IOS_SIGNING_BUNDLE` and `APP_STORE_CONNECT_API_KEY_JSON` as repository Actions secrets. Both release workflows read these names. The table shows where to set environment overrides when using separate upload and App Review credentials.

| Environment | Secret | Contents |
| --- | --- | --- |
| `production` | `IOS_SIGNING_BUNDLE` | Distribution certificate/private key (`.p12`), password and one App Store profile per v2 app, in the JSON format below |
| `production` | `APP_STORE_CONNECT_API_KEY_JSON` | App Store Connect API key for TestFlight uploads |
| `app-store-production` | `APP_STORE_CONNECT_API_KEY_JSON` | App Store Connect API key with App Manager access for review submission |

Use an **App Store Connect team API key**, with the correct app access and sufficient role (Developer for upload; App Manager for submission). Its issuer belongs to Maya Investissement Group Inc. Configure the `app-store-production` environment to allow `main` only and add required reviewers where your GitHub plan permits. The manual job also checks that it was dispatched from `main`.

API key JSON (the `key` field is the full `.p8` contents with JSON-escaped newlines, not base64):

```json
{
  "key_id": "APPLE_KEY_ID",
  "issuer_id": "APPLE_ISSUER_UUID",
  "key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
}
```

Signing JSON (base64 values must be single-line encodings):

```json
{
  "certificate": "BASE64_OF_APPLE_DISTRIBUTION_P12",
  "password": "P12_EXPORT_PASSWORD",
  "profiles": {
    "guardian": "BASE64_OF_GUARDIAN_APP_STORE_MOBILEPROVISION",
    "teacher": "BASE64_OF_TEACHER_APP_STORE_MOBILEPROVISION"
  }
}
```

The `.p12` must contain the private key and an unexpired Apple Distribution certificate from team `SQFU4GGCX2`. Both profiles must include that certificate, match the exact bundle IDs above, and be **App Store distribution** profiles. Development, ad-hoc, wildcard, expired and enterprise profiles are rejected. Enable Push Notifications for both identifiers and Associated Domains for Guardian, then regenerate profiles if capabilities changed. Keep existing Firebase iOS registrations and APNs configuration; the App Store Connect API key is separate from the Firebase/APNs key. See [Apple push notifications](apple-push-notifications.md).

Create both App Store Connect app records before the first upload. Complete agreements, app information, privacy declarations, export compliance, screenshots, review contact and demo access as required. The workflow does not invent compliance answers or replace store metadata. References: [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios), [Fastlane API keys](https://docs.fastlane.tools/app-store-connect-api/), [TestFlight uploads](https://docs.fastlane.tools/actions/upload_to_testflight/).

The sibling frontend's `apple-app-site-association` now includes `SQFU4GGCX2.ca.maya-invest.edaya.guardian` alongside the original identity. Deploy that file to the configured invitation hosts for v2 Universal Links; publishing the mobile app alone does not update the website.

## Build versions and evidence

Marketing versions come from each v2 app's `pubspec.yaml` (for example `1.0.0`). Increase them before the next public App Store version. CI build numbers are `1 + floor(run_number / 100)`, `run_number % 100`, and `run_attempt`, joined with dots: run 142, attempt 2 produces `2.42.2`. This keeps Apple's component limits and gives full reruns a new build number. Attempts above 99 and run numbers above 999899 fail rather than wrap.

If existing TestFlight builds already have larger build numbers for the same marketing version, increment the app's marketing version before onboarding this workflow. Public release versions must be newer than the current public version. The workflow never lets Xcode silently change the selected build number.

The `release-apple-<run_id>-<attempt>` artifact contains both IPAs, qualification evidence and per-app manifests with versions, hashes, source commit and upload status. `uploaded-awaiting-apple-processing` means upload succeeded, not that Apple processing or testing has completed.

## Manual production submission

1. Test the processed builds in TestFlight.
2. Run **Submit TestFlight builds to App Store** from `main`.
3. Enter each app's marketing version and build number from the release summary; no implicit “latest build” selection is used.
4. Leave `automatic_release` false to release manually in App Store Connect after Apple approves, or select it to release automatically after approval.
5. Approve the GitHub environment if reviewers are configured.

Both selections are validated as processed, unexpired iOS builds before either submission. The workflow submits the selected existing binaries for App Review without rebuilding or reuploading them. Apple approval is still required. TestFlight uploading and review submission are serialized by one concurrency group.

The two submissions are not atomic. Evidence is written after each successful submission. On partial failure, inspect App Store Connect and rerun with the same selections: matching builds already in review, pending release or distributed are skipped; a conflicting submitted build or downgrade is rejected. If review rejected a build, address Apple's findings before resubmitting. For failed uploads, rerun **all jobs** of Deploy production to recreate qualification and both platform builds for the new attempt. Do not rerun only the deployment jobs: artifact restoration requires the same run attempt.

## Local verification

```sh
dart run melos run verify
cd tooling/apple
bundle install
bundle exec ruby test/release_test.rb
bundle exec fastlane lanes
```

`fastlane ios build` requires GitHub runner context, qualified inputs and real signing material. `fastlane ios upload_beta` and `fastlane ios submit` perform real store mutations. Without distribution credentials, local unsigned iOS compilation and tooling tests cannot verify the final App Store signing/export or Apple acceptance.
