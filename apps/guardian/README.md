# Edaya Guardian

Flutter app for guardians and parents — Accueil-first IA with live API, auth, and FCM.

**Deferred for v1:** justify absence, pay, reply. Home aggregates client-side.

## Run locally

From the repository root:

```bash
cd apps/guardian
flutter run --dart-define=API_URL=http://10.0.2.2:9999
# Or target staging:
flutter run --dart-define=API_URL=https://staging.api.edayaplus.com
```

## Design review

From the repository root:

```bash
bash scripts/design-review.sh guardian
```

Output: `apps/guardian/design-review/index.html`.

## Specs

- [design-language-spec](../../docs/specs/design-language-spec.md)
- [guardian-shell-spec](../../docs/specs/guardian-shell-spec.md)
- [guardian-shared-components-spec](../../docs/specs/guardian-shared-components-spec.md)
