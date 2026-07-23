# Guardian Shell Spec

> **Applies to:** Guardian Flutter app  
> **Audience:** Implementers and agents  
> **Authority:** This document is normative. Implementations must be cross-checked against it.

This spec defines information architecture, shell chrome, student context, adaptive breakpoints, and list–detail presentation for the Guardian family companion. It does not define color tokens, typography tables, or the full shared-widget catalog.

---

## 1. Product scope

| Rule | Requirement |
|------|-------------|
| Audience | Guardians (parents / legal guardians), French-first |
| Tone | Family companion — not a staff workspace |
| v1 interactions | Mostly **read-only**; guardian **profile** may update contact details and notification channels. Other write flows (justify absence, pay, reply, …) are out of scope until specified |
| Child awareness | When content is student-specific, active student context must remain visible in the shell |

---

## 2. Primary navigation

Exactly **five** primary destinations after authentication:

| Order | Label (FR) | Path | Role |
|-------|------------|------|------|
| 0 | Accueil | `/home` | Action centre — attention, day plan |
| 1 | Agenda | `/calendar` | Merged day list (sessions + school events) |
| 2 | Scolarité | `/scolarite/notes` | Grades and bulletins hub |
| 3 | Frais | `/fees` | Fee summary and lines |
| 4 | Messages | `/inbox` | Inbox list |

Labels must stay short enough for a 390 px width at 200% text scale.

### Scolarité information architecture

- Hub route is **`/scolarite/notes`**.
- There must be **no** top sub-tab bar for Programme / Cahier / Notes / Bulletins.
- Programme, cahier, subject grades, grade detail, and report cards are reached by **drill-down** from the hub (and related detail routes).
- Legacy paths `/scolarite`, `/scolarite/programme`, `/scolarite/cahier`, and `/scolarite/bulletins` must resolve to the hub (`/scolarite/notes`).

### Tab highlighting

| Location family | Selected tab |
|-----------------|--------------|
| `/home…` | Accueil |
| `/calendar…`, `/session…`, `/attendance…` | Agenda |
| `/scolarite…`, `/grade…`, `/report-card…` | Scolarité |
| `/fees…` | Frais |
| `/inbox…` | Messages |
| `/account…`, `/settings…` | None of the five (chrome still shown; no primary tab forced) |

---

## 3. Routes (checkable inventory)

### Shell tabs (list / hub)

| Path | Screen |
|------|--------|
| `/login` | Connexion (outside shell) |
| `/home` | Accueil |
| `/calendar` | Agenda |
| `/scolarite/notes` | Scolarité hub |
| `/fees` | Frais |
| `/inbox` | Messages |

### Detail / drill-down (under shell)

| Path | Screen | List host (expanded drawer) |
|------|--------|-----------------------------|
| `/attendance` | Présences | Agenda |
| `/session/:id` | Séance | Agenda |
| `/scolarite/progress` | Programme overview | Scolarité |
| `/scolarite/period/:periodId/subject/:subject` | Notes matière | Scolarité |
| `/scolarite/subject/:subject/cahier` | Cahier matière | Scolarité |
| `/grade/:id` | Détail note | Scolarité |
| `/report-card/:id` | Bulletin | Scolarité |
| `/fees/fee/:id` | Détail frais | Frais |
| `/fees/payment/:id` | Reçu paiement | Frais |
| `/inbox/message/:id` | Message | Messages |
| `/account` | Compte (full page under shell) | Account |
| `/account/profile` | Profil | Account |
| `/settings` | Paramètres | Account |

Legacy redirects that must remain:

| From | To |
|------|-----|
| `/fee/:id` | `/fees/fee/:id` |
| `/payment/:id` | `/fees/payment/:id` |
| `/message/:id` | `/inbox/message/:id` |
| `/calendar/events` | `/calendar` |

Unauthenticated users must land on `/login`. Authenticated users on `/login` must redirect to `/home`.

---

## 4. Shell chrome

### Brand app bar

- Centered wordmark **`edaya`** (Nunito brand style).
- Canvas background matching the app scaffold (`#F0F7FF`); no elevation tint.
- No automatic back leading on primary shell destinations.

### Student context visibility

Whenever shell chrome is shown (including Accueil, the five primary tabs, their details, **Account**, and **Settings**), the **student context card** must remain part of the chrome. Account is guardian-scoped but still shows the active student/school context so the guardian can switch child without leaving account flows.

### Compact width (&lt; 600)

| Element | Requirement |
|---------|-------------|
| Primary nav | Bottom `NavigationBar` with the five destinations |
| Profile | App bar leading control → `/account` |
| Help | App bar trailing control |
| Student context | `StudentContextCard` below the app bar on destinations that show chrome |

### Medium and wider (≥ 600)

| Element | Requirement |
|---------|-------------|
| Primary nav | Full-height `NavigationRail` (labels always visible) |
| Profile + help | At the **bottom** of the rail (not on the app bar) |
| App bar | Brand wordmark only (no profile / help) |
| Layout | Rail edge-to-edge with content column; app bar lives in the content column so the rail border runs full height |

### Student context card

Must show, for the active student:

- Avatar (photo or initials)
- Student name + class label
- School name + school year
- Affordance to open the **context sheet** (student switcher)

Layout: dual columns — student | school — inside a borderless card under the brand app bar (or under chrome on list masters).

### Context sheet

Opened from the student context card. Must contain:

1. **Mes enfants** — selectable linked students, grouped by school
2. **Année scolaire** — for each school group, a compact year control via overlay menu (`MenuAnchor`) placed beside the school name (not a separate full-width year section, and not an inline list of all years)

Year control must scale as historical years accumulate (scrollable menu; current year remains visible in the closed control). Different schools may have different selected years.

---

## 5. Adaptive breakpoints

| Tier | Width (logical px) | Chrome | Content |
|------|--------------------|--------|---------|
| Compact | &lt; 600 | Bottom navigation | Single column |
| Medium | ≥ 600 and &lt; 1000 | Navigation rail + brand app bar in content column | Max content width **840**; details replace body under chrome (no overlay drawer) |
| Expanded | ≥ 1000 | Rail + right overlay drawer | Detail over list |

Constants (checkable):

| Name | Value |
|------|-------|
| Compact threshold | 600 |
| Expanded (drawer) threshold | 1000 |
| Max content width | 840 |

Prefer a single Agenda-style content column. Must **not** use a permanent side-by-side master–detail split pane.

---

## 6. List–detail presentation

Applies to: Agenda, Scolarité, Frais, Messages, and Account profile/settings.

### Compact / medium (&lt; 1000)

- List (or hub) fills the shell body under chrome.
- Opening a detail **replaces** the body with the detail screen (back returns to the list path).
- Detail uses a back affordance (not close).

### Expanded (≥ 1000)

- List remains full width in the content column.
- Detail opens as a **right overlay drawer**:
  - Default width fraction **0.4** of the host
  - Clamped roughly **360–520** dp and at most **50%** of host width
  - Scrim over the master (~18% black); tap scrim dismisses to the list path via navigation to `listPath`
  - Close control on the detail (×), not a system back in the drawer header
  - Close may **pop when possible**, otherwise navigate to the detail’s `fallbackRoute` / list path — pop-when-possible is allowed even if that path differs slightly from a hard `go(listPath)`
  - Drawer is not permanently split; when there is no selection, only the list is shown
- Drawer must cover the content column from **brand title through bottom** (edge-to-edge with the rail): master column includes app bar + student context + list so the overlay sits on top of that stack.

### Account special case

- `/account` is a full page under the shell (list path for the account host).
- `/account/profile` and `/settings` are details of that host (drawer on expanded; full body when &lt; 1000).

### Home

- Home does **not** use the list–detail drawer host.
- Home shows app bar + student context + page body in the content column.

---

## 7. Checkable invariants (summary)

1. Exactly five primary FR labels: Accueil, Agenda, Scolarité, Frais, Messages.
2. Scolarité hub path is `/scolarite/notes`; no top Programme/Cahier/Notes/Bulletins tab bar.
3. Compact (&lt; 600): bottom nav; profile + help on app bar.
4. ≥ 600: rail; profile + help on rail trailing; brand-only app bar.
5. ≥ 1000: right overlay detail drawer (~40%, scrim, close); no permanent split.
6. Drawer covers title → bottom of the content column beside the rail.
7. Max unconstrained content width 840.
8. Student context card visible whenever shell chrome is shown (including Account / Settings).
9. Year selection only via menu overlay in the context sheet (per school, beside school name).
10. v1 is mostly read-only (profile contact / notification channels allowed); help/settings stubs must not be documented as product features (see §8).
11. Design-review (or equivalent) must cover **compact**, **medium** (rail, no drawer), and **expanded** (rail + drawer) widths.

---

## 8. Non-normative

Must not be treated as shell requirements:

- A `ShellContextBar` with student chip left + guardian chip right as the primary header model
- Scolarité top sub-tabs (Programme / Cahier / Notes / Bulletins)
- Help centre implemented as a SnackBar stub
- Settings controls that are no-ops (dark mode, language) presented as finished product behavior
- Triple paint-path implementation details for the app bar (Scaffold vs chrome wrappers) — only the UX outcomes in §4–§6 are normative
- Deprecated “permanent master–detail” naming or APIs
- Historical redesign tables comparing old production screens
- Web staff patterns (list + URL drawer + mutation modals as the workspace model)
