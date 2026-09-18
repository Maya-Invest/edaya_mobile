# Edaya Teacher — Accueil prototype

Standalone Flutter app for the teacher Accueil-first information architecture. This is the **product surface** for the Accueil cutover. Store-listed [`apps/teacher`](../teacher) stays frozen (four tabs) until a later promotion.

**Live (`melos run run:teacher:prototype`):** Identity email OTP, teacher context from assignments, Accueil tasks, family-feedback avis, and session attendance / logbook / marks against local Identity (`10.0.2.2:9900`) and school API (`10.0.2.2:9999`).

**Tests / design-review:** `MockStore` harness (`live: false`) so screenshots and smoke tests do not need the API.

## Run locally

```bash
melos run run:teacher:prototype
```

Requires local Identity and school API. Default demo email: `a.toure@ecole-ci.edaya.dev` (override with `--dart-define=DEV_TEACHER_EMAIL=...`).

Widget tests:

```bash
cd apps/teacher_prototype
flutter test --exclude-tags integration
```

## Information architecture

Five shell tabs (post-login → `/home`):

| Tab | Route | Role |
|-----|-------|------|
| Accueil | `/home` | Action centre — one primary task + remaining count, current/next session |
| Agenda | `/calendar` | Day list of teacher sessions; week chips + date picker |
| Classes | `/classes` | Assigned classes → roster → student quick profile |
| Évaluations | `/evaluations` | Assessments + **Avis des familles** |
| Messages | `/inbox` | Inbox (empty until messaging is wired live) |

Family feedback from Accueil opens `/home/avis/:id` (Accueil tab stays selected). The archive is `/evaluations/avis`.

Shell chrome: branded `PrototypeAppBar` + live `TeacherContextCard` (class/subject · school/year).

### Adaptive layout

| Width | Chrome | Content |
|-------|--------|---------|
| &lt; 600 | Bottom navigation | Single column |
| ≥ 600 and &lt; 1000 | `NavigationRail` | Max content width ~840; details replace body |
| ≥ 1000 | Rail + right overlay drawer (~40%) | Detail over list |

## Specs

- [Design language](../../docs/specs/design-language-spec.md)
- [Teacher shell](../../docs/specs/teacher-shell-spec.md)
- Shared widgets: [guardian-shared-components-spec](../../docs/specs/guardian-shared-components-spec.md)

## Design review

```bash
melos run screenshots:teacher-prototype:review
```

Output: `apps/teacher_prototype/design-review/index.html` (mock harness, no API).
