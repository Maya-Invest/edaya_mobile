# Edaya Guardian — UI Prototype

Standalone Flutter prototype demonstrating the new Guardian design language with **mock data only**. No API, auth, or production app dependencies.

**Scope (v1):** read-only family companion — Home action centre, merged Agenda, Scolarité hub, fees, and inbox. Guardian write flows (justify absence, pay, reply, …) are deferred to a later version.

## Run locally

```bash
cd apps/guardian_prototype
flutter pub get
flutter run
```

From monorepo root:

```bash
melos run run:guardian:prototype
```

## Demo login

Tap **Se connecter** on the login screen — any credentials work. Mock guardian: **Moussa Koné**, children **Amina** (6ème A) and **Youssef** (3ème B).

## Information architecture

Five shell tabs (post-login → `/home`):

| Tab | Route | Role |
|-----|-------|------|
| Accueil | `/home` | Action centre — overdue fees, bulletin, unread mail, day plan |
| Agenda | `/calendar` | Merged day list (sessions + school events); week chips + date picker |
| Scolarité | `/scolarite/notes` | Grades + bulletins hub; programme / cahier via subject drill-downs |
| Frais | `/fees` | Fee summary, lines, installments |
| Messages | `/inbox` | Inbox list |

Shell chrome: branded `PrototypeAppBar` + `StudentContextCard` (student / school / year). Legacy paths `/calendar/events`, `/scolarite/programme`, `/scolarite/cahier`, and `/scolarite/bulletins` redirect into the screens above.

### Adaptive layout

| Width | Chrome | Content |
|-------|--------|---------|
| &lt; 600 | Bottom navigation | Single column |
| ≥ 600 | `NavigationRail` (profile + help at bottom) | Max content width ~840 |
| ≥ 1000 | Rail + right overlay drawer (~40%) | Detail over list (Agenda, Scolarité, Fees, Inbox) |

## Screens

### Shell tabs

| Route | Screen |
|-------|--------|
| `/login` | Connexion |
| `/home` | Accueil (action centre) |
| `/calendar` | Agenda — séances + événements du jour |
| `/scolarite/notes` | Scolarité — notes et bulletins |
| `/fees` | Frais |
| `/inbox` | Messages |

### Detail / drill-down

| Route | Screen |
|-------|--------|
| `/attendance` | Présences (from Agenda) |
| `/session/:id` | Détail séance |
| `/scolarite/progress` | Programme — progression par matière |
| `/scolarite/period/:periodId/subject/:subject` | Notes d’une matière |
| `/scolarite/subject/:subject/cahier` | Cahier de classe |
| `/grade/:id` | Détail note |
| `/report-card/:id` | Bulletin |
| `/fee/:id` | → `/fees/fee/:id` |
| `/payment/:id` | → `/fees/payment/:id` |
| `/message/:id` | → `/inbox/message/:id` |
| `/fees/fee/:id` | Détail frais (nested; right drawer on tablet) |
| `/fees/payment/:id` | Reçu paiement (nested) |
| `/inbox/message/:id` | Détail message (nested; right drawer on tablet) |
| `/account` | Compte (full page under shell) |
| `/account/profile` | Profil (drawer on tablet) |
| `/settings` | Paramètres (drawer on tablet) |

## Design review screenshots

Generate PNGs for every prototype route (phone + tablet) and an HTML gallery.

**Important:** stop `flutter run` and any other Flutter tests first — a leftover `flutter_tester` process can interfere with screenshot capture.

```bash
# from monorepo root
melos run screenshots:guardian-prototype:review

# or directly
bash scripts/guardian-prototype-design-review.sh
```

Output: `apps/guardian_prototype/design-review/index.html` (mock data, no API). Expect ~10 seconds on a clean machine (38 PNGs).

## Design spec

See [`docs/specs/design-language-spec.md`](../../docs/specs/design-language-spec.md).

## Phase 3

Production integration checklist: [`docs/plans/guardian-phase3-migration.md`](../../docs/plans/guardian-phase3-migration.md).

Levit: app `LScope` + feature `LScopedView` controllers over `MockStore` (see `lib/di/prototype_module.dart`). Phase-3 swaps the store for API clients.
