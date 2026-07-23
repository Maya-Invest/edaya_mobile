# Edaya Teacher — UI Prototype

Standalone Flutter prototype demonstrating the teacher Accueil-first information architecture with the **guardian design language** and **mock data only**. No API or auth dependencies. Production [`apps/teacher`](../teacher) stays frozen.

**Scope (v1):** daily teacher jobs — Home action centre, Agenda, Classes, Évaluations (marks + bulletin comments), and inbox. Writes update the in-memory `MockStore`.

## Run locally

```bash
cd apps/teacher_prototype
flutter pub get
flutter run
```

From monorepo root:

```bash
melos run run:teacher:prototype
```

## Demo login

Tap **Se connecter** — any credentials work. Mock teacher: **Aminata Traoré**, classes **6ème A**, **5ème B** (titulaire), **3ème A** at Collège Moderne Plateau.

## Information architecture

Five shell tabs (post-login → `/home`):

| Tab | Route | Role |
|-----|-------|------|
| Accueil | `/home` | Action centre — incomplete attendance/logbook/marks/comments, current/next session |
| Agenda | `/calendar` | Day list of teacher sessions; week chips + date picker |
| Classes | `/classes` | Assigned classes → roster → student quick profile |
| Évaluations | `/evaluations` | Assessments + report-card drill-down |
| Messages | `/inbox` | Inbox list |

Shell chrome: branded `PrototypeAppBar` + `TeacherContextCard` (class/subject · school/year).

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

Output: `apps/teacher_prototype/design-review/index.html` (mock data, no API).
