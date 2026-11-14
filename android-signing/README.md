# Android release signing

Play Store uploads require a release-signed Android App Bundle (`.aab`).

Run commands below from the repository root.

## One-time setup

```bash
dart run edaya_repo:repo maintenance keystore
```

This creates `edaya-upload.jks` in this directory and writes `key.properties` for both apps.
**Back up the keystore and passwords** — you need the same upload key for every future release.

To use your own keystore instead, copy `key.properties.example` to:

- `apps/guardian/android/key.properties`
- `apps/teacher/android/key.properties`

Set `keyAlias` to `guardian` or `teacher` respectively.

## Build release bundles

```bash
dart run edaya_repo:repo build production
# Both v2 apps are always built.
```

Outputs:

- `apps/guardian/build/app/outputs/bundle/release/app-release.aab`
- `apps/teacher/build/app/outputs/bundle/release/app-release.aab`

The build target selects the API URL: staging uses `https://staging.api.edayaplus.com`; production uses `https://api.edayaplus.com`. CI restores the existing upload keys from `ANDROID_SIGNING_BUNDLE`. Keep the `guardian` and `teacher` aliases and store identities; do not create replacement keys for the v2 migration.
