# Android release signing

Play Store uploads require a release-signed Android App Bundle (`.aab`).

## One-time setup

```bash
melos run android:keystore:create
```

This creates `edaya-upload.jks` in this directory and writes `key.properties` for both apps.
**Back up the keystore and passwords** — you need the same upload key for every future release.

To use your own keystore instead, copy `key.properties.example` to:

- `apps/guardian/android/key.properties`
- `apps/teacher/android/key.properties`

Set `keyAlias` to `guardian` or `teacher` respectively.

## Build release bundles

```bash
melos run build:play:aab
```

Outputs:

- `apps/guardian/build/app/outputs/bundle/release/app-release.aab`
- `apps/teacher/build/app/outputs/bundle/release/app-release.aab`

Staging API URL (`https://staging.api.edayaplus.com`) is baked in via `--dart-define=API_URL=...`.
Override with `EDAYA_API_URL` when building (for example production: `https://api.edayaplus.com`).
