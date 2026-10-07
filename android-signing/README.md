# Android release signing

Play Store uploads require a release-signed Android App Bundle (`.aab`).

Run commands below from the repository root.

## One-time setup

```bash
bash scripts/create-android-keystore.sh
```

This creates `edaya-upload.jks` in this directory and writes `key.properties` for both apps.
**Back up the keystore and passwords** — you need the same upload key for every future release.

To use your own keystore instead, copy `key.properties.example` to:

- `apps/guardian/android/key.properties`
- `apps/teacher/android/key.properties`

Set `keyAlias` to `guardian` or `teacher` respectively.

## Build release bundles

```bash
EDAYA_API_URL=https://api.edayaplus.com bash scripts/build-play-aab.sh
# Append guardian or teacher to build just one app.
```

Outputs:

- `apps/guardian/build/app/outputs/bundle/release/app-release.aab`
- `apps/teacher/build/app/outputs/bundle/release/app-release.aab`

`EDAYA_API_URL` is required and is baked in via `--dart-define=API_URL=...`.
Use `https://staging.api.edayaplus.com` for staging or `https://api.edayaplus.com` for production. With no app argument, both apps are built.
