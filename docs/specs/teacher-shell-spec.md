# Teacher Shell Spec

> **Applies to:** Teacher Flutter prototype (`apps/teacher_prototype`) and future teacher production shell  
> **Audience:** Implementers and agents  
> **Authority:** This document is normative for the teacher Accueil-first shell. Visual tokens live in [design-language-spec.md](design-language-spec.md). Shared widgets follow [guardian-shared-components-spec.md](guardian-shared-components-spec.md) unless a teacher-specific component is listed below.

This spec defines information architecture, shell chrome, teacher/class context, adaptive breakpoints, and list–detail presentation for the teacher daily command center.

---

## 1. Product scope

| Rule | Requirement |
|------|-------------|
| Audience | Teachers (subject and homeroom), French-first |
| Tone | Staff classroom companion — polished like guardian, job-oriented |
| Auth | Pre-shell email OTP against Identity (`sendEmailOtp` / `signInWithEmailOtp`). Success lands on `/home`. Widget tests may keep a mock OTP harness; the runnable product (`melos run run:teacher:prototype`) is live. |
| Live after OTP | Shell teacher context (class / subject / year), Accueil tasks, and family-feedback avis must read the school API. Do not ship real Identity in front of fake classrooms. |
| Other hubs | Agenda sessions, class rosters, marks, attendance, and logbook resolve live IDs when those controllers are wired. Inbox and bulletin comments may stay empty/mock until a later cutover. |
| Context awareness | Active class/subject and school year must remain visible in the shell whenever chrome is shown |

---

## 2. Primary navigation

Exactly **five** primary destinations after authentication:

| Order | Label (FR) | Path | Role |
|-------|------------|------|------|
| 0 | Accueil | `/home` | Today action centre — incomplete tasks, current/next session |
| 1 | Agenda | `/calendar` | Day/week teacher sessions |
| 2 | Classes | `/classes` | Assigned classes → roster → student quick profile |
| 3 | Évaluations | `/evaluations` | Assessments hub + report-card drill-down |
| 4 | Messages | `/inbox` | Inbox list |

Labels must stay short enough for a 390 px width at 200% text scale.

### Tab highlighting

| Location family | Selected tab |
|-----------------|--------------|
| `/home…` (including `/home/avis…`) | Accueil |
| `/calendar…`, `/session…` | Agenda |
| `/classes…`, `/student…` | Classes |
| `/evaluations…`, `/report-card…` | Évaluations |
| `/inbox…` | Messages |
| `/account…`, `/settings…` | None of the five (chrome still shown; no primary tab forced) |

---

## 3. Routes (checkable inventory)

### Shell tabs (list / hub)

| Path | Screen |
|------|--------|
| `/login` | Connexion OTP (outside shell) |
| `/home` | Accueil |
| `/calendar` | Agenda |
| `/classes` | Classes hub |
| `/evaluations` | Évaluations hub |
| `/evaluations/avis` | Avis des familles (list) |
| `/inbox` | Messages |

### Detail / drill-down (under shell)

| Path | Screen | List host (expanded drawer) |
|------|--------|-----------------------------|
| `/home/avis/:id` | Avis (from Accueil; Accueil tab stays selected) | Home (focused page, no drawer host) |
| `/session/:id` | Séance | Agenda |
| `/session/:id/attendance` | Présences | Agenda |
| `/session/:id/logbook` | Cahier de texte | Agenda |
| `/classes/:classId` | Roster | Classes |
| `/classes/:classId/student/:studentId` | Profil élève | Classes |
| `/evaluations/avis/:id` | Avis (from Évaluations hub) | Évaluations |
| `/evaluations/:evaluationId/marks` | Saisie notes | Évaluations |
| `/evaluations/report-cards/:classId/:periodId` | Roster bulletin | Évaluations |
| `/evaluations/report-cards/:classId/:periodId/:rosterId` | Commentaire | Évaluations |
| `/inbox/message/:id` | Message | Messages |
| `/account` | Compte | Account |
| `/account/profile` | Profil | Account |
| `/settings` | Paramètres | Account |

Legacy redirects:

| From | To |
|------|-----|
| `/message/:id` | `/inbox/message/:id` |

Unauthenticated users must land on `/login`. Authenticated users on `/login` must redirect to `/home`.

### Accueil tasks

Accueil shows **one** primary “À traiter” card plus a remaining-count line. Order:

1. Open family-feedback results (`/home/avis/:id`)
2. Incomplete attendance
3. Logbook for lessons that have already ended today
4. Marks to enter
5. Bulletin comments (when present)
6. Unread messages (when present)

The full family-feedback archive stays under Évaluations (`/evaluations/avis`), not a Teaching tab.

---

## 4. Shell chrome

### Brand app bar

- Centered wordmark **`edaya`** (Nunito brand style).
- Canvas background matching the app scaffold (`#F0F7FF`); no elevation tint.
- No automatic back leading on primary shell destinations.

### Teacher context visibility

Whenever shell chrome is shown (including Accueil, the five primary tabs, their details, **Account**, and **Settings**), the **teacher context card** must remain part of the chrome.

### Compact width (&lt; 600)

| Element | Requirement |
|---------|-------------|
| Primary nav | Bottom `NavigationBar` with the five destinations |
| Profile | App bar leading control → `/account` |
| Help | App bar trailing control |
| Teacher context | `TeacherContextCard` below the app bar |

### Medium and wider (≥ 600)

| Element | Requirement |
|---------|-------------|
| Primary nav | Full-height `NavigationRail` (labels always visible) |
| Profile + help | At the **bottom** of the rail |
| App bar | Brand wordmark only |
| Layout | Rail edge-to-edge with content column |

### Teacher context card

Must show, for the active assignment:

- Avatar (photo or initials)
- Class label + subject (with “Titulaire” when homeroom)
- School name + school year
- Affordance to open the **context sheet** (class / year switcher)

Layout: dual columns — class/subject | school/year — inside a borderless card under the brand app bar.

### Context sheet

Opened from the teacher context card. Must contain:

1. **School + année scolaire** — year via `MenuAnchor` / `AcademicYearPicker`
2. **Mes classes** — selectable class/subject assignments

---

## 5. Adaptive breakpoints

Same as guardian:

| Tier | Width (logical px) | Chrome | Content |
|------|--------------------|--------|---------|
| Compact | &lt; 600 | Bottom navigation | Single column |
| Medium | ≥ 600 and &lt; 1000 | Navigation rail + brand app bar | Max content width **840**; details replace body |
| Expanded | ≥ 1000 | Rail + right overlay drawer | Detail over list |

| Name | Value |
|------|-------|
| Compact threshold | 600 |
| Expanded (drawer) threshold | 1000 |
| Max content width | 840 |

---

## 6. List–detail presentation

Applies to: Agenda, Classes, Évaluations, Messages, and Account profile/settings.

### Compact / medium (&lt; 1000)

- List fills the shell body under chrome.
- Opening a detail **replaces** the body (back returns to the list path).

### Expanded (≥ 1000)

- List remains full width; detail opens as a **right overlay drawer** (~40%, clamp 360–520, scrim, × close) covering title → bottom beside the rail.

### Home

- Home does **not** use the list–detail drawer host.

---

## 7. Teacher-specific components

| Component | Role |
|-----------|------|
| `TeacherContextCard` | Shell class/subject + school/year card (replaces guardian `StudentContextCard`) |

All other chrome and list widgets reuse the guardian design-language catalog.

---

## 8. Checkable invariants (summary)

1. Exactly five primary FR labels: Accueil, Agenda, Classes, Évaluations, Messages.
2. Compact (&lt; 600): bottom nav; profile + help on app bar.
3. ≥ 600: rail; profile + help on rail trailing; brand-only app bar.
4. ≥ 1000: right overlay detail drawer; no permanent split.
5. Max unconstrained content width 840.
6. Teacher context card visible whenever shell chrome is shown.
7. Post-login landing is `/home`.
8. Design-review (or equivalent) must cover compact, medium, and expanded widths.
9. Login is Identity OTP (not “any code works”) on the runnable prototype.
10. Accueil family-feedback tasks and `/evaluations/avis` read live teacher results.
