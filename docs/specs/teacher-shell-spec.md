# Teacher Shell Spec

> **Applies to:** Teacher Flutter production shell (`apps/teacher`)
> **Audience:** Implementers and agents  
> **Authority:** This document is normative for the teacher Accueil-first shell. Visual tokens live in [design-language-spec.md](design-language-spec.md). Shared widgets follow [guardian-shared-components-spec.md](guardian-shared-components-spec.md) unless a teacher-specific component is listed below.

This spec defines information architecture, shell chrome, teacher/class context, adaptive breakpoints, and list–detail presentation for the teacher daily command center.

---

## 1. Product scope

| Rule | Requirement |
|------|-------------|
| Audience | Teachers (subject and homeroom), French-first |
| Tone | Staff classroom companion — polished like guardian, job-oriented |
| Auth | Pre-shell email OTP against Identity (`sendEmailOtp` / `signInWithEmailOtp`). Success lands on `/home`. Widget tests may keep a mock OTP harness; the runnable product (`cd apps/teacher && flutter run --dart-define=API_URL=http://10.0.2.2:9999`) is live. |
| Live after OTP | Shell teacher context (class / subject / year), Accueil tasks, family-feedback avis, inbox, and bulletin comments must read the school API. Do not ship real Identity in front of fake classrooms. |
| Other hubs | Agenda sessions, class rosters, marks, attendance, logbook, evaluations, and report-card comments resolve live IDs. |
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

- Authenticated chrome uses the supplied EDAYA logo artwork. Do not reconstruct a typed `edaya` wordmark.
- Canvas background follows the active theme surface.
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
9. Login is Identity OTP (not “any code works”) on the runnable product.
10. Accueil family-feedback tasks and `/evaluations/avis` read live teacher results.

## Guardian conversations

The existing inbox merges notifications with guardian conversation previews. `/inbox/conversation/:conversationId` shows captured school/child/participants, chronological messages and an online reply composer. Explain authorized school oversight. Losing the original teaching relationship removes access; another teacher never inherits the thread. Unread positions belong to the selected profile. Poll only visible messaging surfaces in the foreground; refresh on resume and push.

## Teacher signature in Account → Profile

Profile exposes a Signature action for the current teacher and school. Its route-scoped controller shows the current private signature, optional draft preview, save progress and translated retry feedback. Draw supports undo/clear; gallery/camera images use a dedicated rectangular crop/rotation editor. Export preserves proportions and transparency in a PNG no larger than 1024 pixels per side or 1 MiB. A preview precedes explicit Save. Saving authorizes automatic use beside each subject/homeroom name on periodic/annual bulletins and the teacher author's name on incident reports. Signatures remain optional.

Replacement creates a new private upload; failures preserve the saved signature and draft. Retry reuses the upload/command identity where safe. Removal requires confirmation explaining that already requested and issued documents retain their signatures. Profile/school changes and sign-out discard drafts, editor images and retry state and ignore late responses. Controls require French/English labels and semantics. Draw/crop editors belong to the teacher feature, rather than the shared portrait editor, which exports square JPEGs.

The signature drawing editor uses the `signature` package and its controller for drawing, undo, clear, and transparent PNG export. Exported images pass through the shared signature bounds and size normalization before preview and save.

## Teacher v2 navigation

The copy in `apps/teacher` uses the existing EDAYA tokens, Poppins/Inter and components. Home is the navigation root. Full destinations have **Retour**; records, forms and pickers use one bottom sheet with **Fermer**. Browser Back dismisses that sheet before leaving the destination. Sheet closure retains the invoking list, scroll position and focus. Dirty forms ask whether to continue or abandon the entry.

### Exact assignment context

A workspace is school + published academic year + class + subject. A missing subject is valid only for a titulaire who has no teaching assignment in that class. The single context sheet displays school headings with selectable class–subject entries. It adds **Titulaire** to teaching entries when relevant and uses a class-only titulaire entry only when no subject is taught there. School headings do not select a workspace. There is no all-class selection, separate school switcher or post-login chooser in teacher_v2.

Restore the exact assignment per authenticated teacher, school and year. On first use choose the first eligible entry ordered by school, class and subject. Replace a revoked selection with a valid entry and explain the change. An empty assignment set shows an unavailable state. Switch school, grants, published year and assignment together; discard stale responses from the previous scope. The school year remains visible as read-only context. Original teacher and guardian selection flows are unchanged. Home and the picker share the teacher’s class labels and attendance modes. Picker data can be reused for up to one minute, or until an assignment starts or ends, whichever comes first. Activating another school rechecks its published year, grants and assignments before displaying the chosen class.

### Home and destination availability

On mobile and tablet the grid starts directly with the first available activity group. Equal `SurfaceCard` tiles use two phone columns and three tablet columns where space allows. **Enseignement** contains Agenda, Progression, Évaluations and Bulletins, in that order. **Vie en classe** contains Messages, Avis and Incidents. Show Bulletins only to the selected class’s titulaire. Progression, Évaluations and Avis require a subject. The upper-right **Mon profil** button in the Home app bar opens the account-wide profile, including for a teacher without an assignment. Teachers find pupils in the activity that needs them. Former class-list bookmarks return to Home and old individual pupil links open the identity sheet above Home.

**Séances du jour**, **Enseignement** and **Vie en classe** use the same heading size. An empty session preview displays plain text below the heading. Show eligible daily roll-call first, then the current and next lesson, or the next two today. While Home is visible and the app is active, refresh the school day on entry, on resume, and once per minute. Keep confirmed lessons visible through slow or failed reads for that assignment, with a retry on failure. Re-evaluate the preview at lesson boundaries and school midnight. Lessons follow the selected subject and actual lesson grants; class activities follow the class. Landscape tablet places daily work beside the grid; portrait places it above. Profile remains account-wide, lists assignments and presents settings once. School-wide notices remain under **Établissement**; unattributed feedback remains under **Sans classe précisée**.

### Évaluations and Bulletins

Évaluations opens with the period selector and **Moyenne de la période / Évaluations** tabs. Default to the current period and its average. The evaluation chooser scrolls with the content and lists evaluations newest first. Average values use tinted containers. Changing period or assignment returns to the average. Create/duplicate in a sheet with the selected teaching context and select the saved assessment. Both tabs have a labeled New evaluation FAB on phones. At 600dp and above the filled creation button sits beside the period selector.

Average rows use the authorized server subject-period summary: submitted official results, canonical coefficients and grading rules, active eligible pupils plus retained assessment pupils, contributing assessments and only the teacher's own subject-comment state. Draft marks and pending proposals do not change averages. No eligible result displays an unavailable value, never zero. Pupils without academic records remain visible. A prepared subject section is required to edit its appreciation. This view has no submission panel.

An evaluation uses its authorized roster and submission snapshot. Draft rows show inline numeric inputs or mention selectors and a three-dot menu for absence, exemption and clearing an entry. Input changes remain local until **Enregistrer / Save** or **Soumettre les notes / Submit marks**. The fixed bottom panel shows completion and unsaved/queued state. Save accepts incomplete drafts; Submit saves valid completed entries, flushes queued writes and submits against the confirmed revision. Keep the final pupil above the footer and keyboard. Protect Back and period, evaluation, class or school changes with Save, Discard and Continue editing.

After submission, remove the class-wide action panel. Each row shows official and pending results with **Modifier la note / Edit mark**. One pupil-specific sheet contains the proposed result and required approval reason, with Send request, Update request and authorized withdrawal. New requests affect one pupil. Revising or withdrawing one pupil from an older grouped request preserves its other proposals and read-only shared reason. No correction history is exposed.

Bulletins is restricted to the selected class's titulaire. Its period picker opens the pupil list directly. Each pupil sheet shows all subject aggregates and teachers' appreciations, then the separately editable general comment. Subject appreciations are edited through Évaluations. Unprepared bulletins remain explicit in the list. Draft saves and published-comment approval rules remain unchanged, including **Approuvée · En attente de publication**. Stale snapshots are distinguished from current calculated results; viewing never generates or publishes documents.

### Routes and design details

Preserve existing deep links. Assessment links select their authorized teaching assignment and evaluation. Former subject-teacher bulletin links resolve to the subject average/comment view. Home, Agenda and Progression open a full session page. The Appel and Cahier de texte tabs share one lesson controller. Logbook and attendance links select the corresponding tab. The logbook editor opens in one sheet above the session. Pending proposals stay on their source records without a teacher approval-history destination.

Home tiles use theme surface fills, 16dp token radii, soft shadows, primary-container icon wells, 16dp phone gutters and 24dp section spacing. Feature pages use 18sp titles with the context switch constrained and ellipsized on the title row. On phones with enlarged text, place the picker below the title. Home typography, context, spacing and layout remain unchanged. Agenda keeps previous/next-week chevrons, 4dp day spacing and scrollable 48dp day targets at narrow widths. Use **Cahier de texte** in French and **Logbook** in English.

Current implementations are `workspace_home.dart`, `workspace_navigation.dart`, `teacher_gradebook_page.dart` and `workspace_classes.dart`. Chrome evidence and verification outcomes live in `bin/audits/edaya-teacher-ux-2026-11-03`.

### Daily and lesson roll call

Both registers open on the ordered pupil list. Present and Absent save a draft. The photo view advances after a saved choice, and the last pupil returns the teacher to the list. Only **Terminer** on a complete, synchronized roster submits the register. Submitted pupil details support attendance corrections, late arrivals, and one timed departure during the active window. Departure preserves the original attendance status. Teacher comments and staff justifications are separate.

### Responsive detail workspaces in teacher_v2

Home aligns its title and profile action with the assignment card. The localized profile action has a 68 dp minimum height, a leading teacher portrait when available, an account icon otherwise, a visible label, blue hover feedback and a keyboard focus outline. Wide detail pages retain the same Retour and Fermer navigation as phone pages. Progression pairs chapter coverage with dated cahiers. Gradebook rows keep the pupil above the mark summary at every width. The roll-call Finish action shows the recorded count under its label in the phone Actions sheet and inline on tablets. Expanded bulletin sheets pair subject results with the general comment, and average sheets pair official contributions with the appreciation. Messages separates conversations from school notices; survey, incident and lesson records pair related sections within their sheets. Account actions precede assignments and synchronization in reading order. At narrow widths and enlarged text these sections stack. Agenda retains its existing day and week layout.

Session tabs pair an icon with each label. The logbook has separate General information and Chapters covered sections. A general sheet edits the note, objectives, homework and family summary. Add chapter selects an existing item from the assignment’s programme; the chapter editor records whether the teacher completed it in this session, defaults new entries to Covered and allows removal. Both editors preserve the other section, keep their own local draft and show pending changes beside the affected official value.

## Offline demo

**Try demo** opens Aminata Traoré’s teaching workspace on 10 November 2026. She teaches mathematics to 6e A and 6e B and is the homeroom teacher for 6e B. The local school supports roll call, logbooks, marks, report comments, incidents, family messages and the signature editor. Requests that need a school reviewer stay pending. Sample published and reviewed records are available separately. The app restores the same workspace at launch until the teacher confirms **Exit demo** in Account.


Teacher Progress uses Chapters / Logbook tabs, initially Chapters. Messages uses Conversations / Notifications, initially Conversations, with composition only in Conversations and pull-to-refresh on both tabs including empty lists. Refresh buttons are omitted; surveys retain their destination.

Agenda uses Schedule / History tabs, initially Schedule, with route-backed selection and retained scroll on detail return. History includes ended sessions newest first within the selected school/year/class context. Completion comes from saved occurrence attendance/logbook state. Load older reads bounded date windows back to the year start. Daily register and session attendance-taking workflows remain available. Below 600dp a labeled FAB opens the Actions sheet for multiple commands. Each pupil’s Present and Absent options keep their icon and full label on a separate row. Save and Cancel remain visible within editors.
