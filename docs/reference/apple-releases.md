# Apple releases

Both stores now publish the v2 workspaces. Android keeps its existing package IDs and upload keys. Apple uses these existing v2 registrations:

| App key | Workspace | iOS bundle ID | Apple team |
| --- | --- | --- | --- |
| `guardian` | `apps/guardian` | `ca.maya-invest.edaya.guardian` | `SQFU4GGCX2` |
| `teacher` | `apps/teacher` | `ca.maya-invest.edaya.teacher` | `SQFU4GGCX2` |

`tooling/apple/apps.json` is the Apple release configuration. Each app key maps to its workspace and selects its signing profile. iOS bundle IDs intentionally differ from Android IDs.

## Pipeline

**Deploy testing** and **Deploy live** each qualify the pushed commit and build each app/platform pair independently. Both apps use Swift Package Manager for native Flutter plugins. Each Apple build restores the verified client, source and Dart lockfile, and runs on macOS 15 with Flutter 3.44.8, Xcode 26.1.1, Ruby 3.3 and the locked Fastlane dependencies. The IPA check verifies the bundle ID, signing certificate, team, build number and distribution push entitlement.

| Branch | Compiled API | Delivery |
| --- | --- | --- |
| `staging` | `https://staging.api.edayaplus.com` | Upload both signed IPAs to TestFlight and wait for processing |
| `main` | `https://api.edayaplus.com` | Upload fresh production IPAs, wait for processing and submit those exact builds for App Review |

Create an internal TestFlight group with automatic distribution for each app and add testers. Complete any encryption/export compliance prompts in App Store Connect. On staging, verify both apps are installable by that group. On production, the job reads each version and build number from its own upload evidence, verifies the source commit and app identity, and checks that Apple has processed both builds before submitting either. After approval, release manually in App Store Connect.

The Apple job uses a temporary signing keychain and removes restored signing material after the build. GitHub artifacts include signed IPAs and per-app evidence.

## Credentials

GitHub has `IOS_SIGNING_BUNDLE` and `APP_STORE_CONNECT_API_KEY_JSON` as repository Actions secrets. Both branches use them. The distribution bundle contains the certificate, private key, password and an App Store profile for each app. The team key must cover both app records and have App Manager access for production submission. When using separate environment secrets, a Developer key suffices in `staging` and an App Manager key is required in `production`.

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

Marketing versions come from each v2 app's `pubspec.yaml` (for example `1.0.0`). Increase them before the next public App Store version. Both entry points use the same prepared `storeBuild`, the number of ten-second intervals since January 1, 2020 UTC. The iOS build number is `1 + floor(storeBuild / 10000)`, `floor(storeBuild / 100) % 100`, and `storeBuild % 100`, joined with dots. For example, `21000001` produces `2101.0.1`. A full rerun at the branch tip receives a fresh number. The build fails if it would exceed `9999.99.99`.

If existing TestFlight builds already have larger build numbers for the same marketing version, increment the app's marketing version before onboarding this workflow. Public release versions must be newer than the current public version. The workflow never lets Xcode silently change the selected build number.

Each `stage-ios_<app>-<run_id>-<attempt>` artifact contains one signed IPA and its manifest on release branches. The `qualified` artifact binds their hashes to the passed stages. Separate `receipts-ios-<app>-<phase>-<run_id>-<attempt>` artifacts record each successful upload and review submission.

If a delivery fails, inspect both apps in App Store Connect. Uploads and review submissions are per app. Resolve any existing review conflict before rerunning **all jobs** so qualification and release share the new attempt number. Apple must accept the marketing version for each app. A different build already in review for that version requires an operator decision in App Store Connect.

## Local verification

```sh
dart run melos run verify
cd tooling/apple
bundle install
bundle exec ruby test/release_test.rb
bundle exec fastlane lanes
```

`fastlane ios build` requires GitHub runner context, verified prepared inputs and real signing material. `fastlane ios upload_beta` and `fastlane ios submit` perform real store mutations. Without distribution credentials, local unsigned iOS compilation and tooling tests cannot verify the final App Store signing/export or Apple acceptance.
