# Edaya Teacher

Flutter app for teachers — Accueil-first IA with live Identity OTP, school API, FCM, and offline outbox.

Store identity: Android/iOS `ca.mayainvest.edaya.staff`.

## Run locally

From the repository root:

```bash
cd apps/teacher
flutter run --dart-define=API_URL=http://10.0.2.2:9999
# Or target staging:
flutter run --dart-define=API_URL=https://staging.api.edayaplus.com
```

Requires the local API (`10.0.2.2:9999`) for emulator runs. Default demo email: `a.toure@ecole-ci.edaya.dev`.

Widget tests (mock harness, no API):

```bash
cd apps/teacher
flutter test --exclude-tags 'integration || staging || design-review'
```

## Information architecture

Five shell tabs (post-login → `/home`):

| Tab | Route | Role |
|-----|-------|------|
| Accueil | `/home` | Action centre — one primary task + remaining count, current/next session |
| Agenda | `/calendar` | Day list of teacher sessions; week chips + date picker |
| Classes | `/classes` | Assigned classes → roster, teaching progress, cahier history |
| Évaluations | `/evaluations` | Assessments, marks, bulletins, family-feedback avis |
| Messages | `/inbox` | Inbox list + message detail |

Family feedback from Accueil opens `/home/avis/:id` (Accueil tab stays selected). The archive is `/evaluations/avis`.

## Specs

- [Design language](../../docs/specs/design-language-spec.md)
- [Teacher shell](../../docs/specs/teacher-shell-spec.md)
- Shared widgets: [guardian-shared-components-spec](../../docs/specs/guardian-shared-components-spec.md)

## Design review

From the repository root:

```bash
bash scripts/design-review.sh teacher
```

Output: `apps/teacher/design-review/index.html` (mock harness, no API).
