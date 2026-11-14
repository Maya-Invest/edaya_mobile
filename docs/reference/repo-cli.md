# Repository commands


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

Use `dart run edaya_repo:repo build staging` for both signed APKs, or `build production` for both signed AABs. CI uses Java 17 and Flutter 3.44.8. Environment secret `ANDROID_SIGNING_BUNDLE` contains the existing keystore/apps bundle with guardian and teacher aliases/passwords and each Firebase configuration. Local builds can use existing private signing files. Missing credentials, debug certificates, app ID mismatches or signature verification errors block output.

Signed builds use the qualified source and transferred generated client. APK verification uses apksigner/aapt; AAB verification uses jarsigner/keytool, with signing certificate provenance and SHA-256 artifact hashes in `.release/manifest.json`. CI uploads those exact files; it does not submit to a store or add iOS delivery. Restored private signing files are cleaned up on failure and success.

Brand tokens, galleries, design review, keystore setup and SVG/native icon generation are Dart/Flutter commands under `generate` and `maintenance`. The asset generator runs through Flutter rendering; Node is no longer needed.

<!-- repo-commands:start -->

```text
Usage: dart run edaya_repo:repo <command>
check                       Prepared client and brand integrity
 test unit|tooling|integration [api|guardian_v2|teacher_v2]
 build staging|production   Signed APK/AAB artifacts
 generate client [staging|production] [--ref REF | --backend-root PATH]
 generate brand|gallery|assets|commands|reviewed-brand-baseline
 dev guardian|teacher
 maintenance keystore|fix|design-review|smoke
 ci verify|qualify|integration|validate-integration|workflows|signing-cleanup
```

<!-- repo-commands:end -->
