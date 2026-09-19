# Edaya Guardian

Flutter app for guardians and parents — Accueil-first IA with live API, auth, and FCM.

**Deferred for v1:** justify absence, pay, reply. Home aggregates client-side.

## Run locally

```bash
cd apps/guardian
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:9999
```

From monorepo root:

```bash
melos run run:guardian:local
melos run run:guardian:staging
```

Archived pre-cutover IA: `apps/guardian_legacy` (`melos run run:guardian:legacy:local`).

## Design review

```bash
melos run screenshots:guardian:review
```

Output: `apps/guardian/design-review/index.html`.

## Specs

- [design-language-spec](../../docs/specs/design-language-spec.md)
- [guardian-shell-spec](../../docs/specs/guardian-shell-spec.md)
- [guardian-shared-components-spec](../../docs/specs/guardian-shared-components-spec.md)
