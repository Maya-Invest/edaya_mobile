# Edaya Teacher

Flutter app for teachers — Accueil-first IA with live Identity OTP, school API, FCM, and offline outbox.

Android identity: `ca.mayainvest.edaya.teacher`. iOS identity: `ca.maya-invest.edaya.teacher`, signed by Maya Investissement Group Inc. (`SQFU4GGCX2`) in Debug, Profile and Release, with its own Firebase iOS registration.

## Apple push notifications

The iOS target includes the push entitlement and background modes. Complete the [Apple/Firebase account setup and device validation](../../docs/reference/apple-push-notifications.md) to enable delivery.

## Run locally

### Full review data in VS Code

Open `edaya.code-workspace` in the parent directory. With the Flutter extension installed, select an iPad simulator from the device selector. In Run and Debug, choose **Teacher v2 · Full review data (iPad)** and press **F5**.

The **Prepare teacher review data** terminal prints `Teacher review data ready` once both campuses are seeded. It stays open to serve the data. F5 then runs **Check teacher review API** and launches Flutter when the API responds on port 19998. Sign in with the prefilled `k.diomande@ecole-ci.edaya.dev` to review subject teaching and titulaire activities together. Use `a.toure@ecole-ci.edaya.dev` for subject teaching across campuses or `m.konan@ecole-ci.edaya.dev` for a titulaire-only class. The debug verification field fills automatically.

Keep the preparation task running to retain your review edits across app restarts. Use **Tasks: Terminate Task → Prepare teacher review data** when finished. The next run seeds a fresh school. This workspace profile requires the sibling backend and the review seeder under the parent directory’s `bin/audits`.

### Standard debug run

From the repository root:

```bash
cd apps/teacher
# iOS Simulator debug (uses localhost:9999)
flutter run
# Android emulator with the local API
flutter run --dart-define=API_URL=http://10.0.2.2:9999
# Or target staging:
flutter run --dart-define=API_URL=https://staging.api.edayaplus.com
```

When the local API advertises test OTP support, the debug verification screen fills the empty verification field and shows a test-mode hint. Tap Verify to submit the code. Explicit API overrides take precedence over the simulator default. Default demo email: `a.toure@ecole-ci.edaya.dev`.

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
dart run edaya_repo:repo maintenance design-review teacher
```

Output: `apps/teacher/design-review/index.html` (mock harness, no API).
