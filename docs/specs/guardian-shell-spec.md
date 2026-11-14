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
| v1 interactions | Mostly **read-only**; guardian **profile** may update contact details and notification channels. Text conversations and replies are supported in Messages. Other write flows (justify absence, pay, …) are out of scope until specified |
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
| 4 | Messages | `/inbox` | Inbox: Messages and Avis |

Labels must stay short enough for a 390 px width at 200% text scale.

### Scolarité information architecture

- Hub route is **`/scolarite/notes`**.
- There must be **no** top sub-tab bar for Programme / Cahier / Notes / Bulletins.
- Programme, cahier, subject grades, grade detail, and report cards are reached by **drill-down** from the hub (and related detail routes).
- Legacy paths `/scolarite`, `/scolarite/programme`, `/scolarite/cahier`, and `/scolarite/bulletins` must resolve to the hub (`/scolarite/notes`).
- There is **no Documents destination** (no sixth tab, no Scolarité “Documents” hub row). Print from the owning object: bulletin PDF on the bulletin detail; receipts/invoices/statement on Frais.

### Messages information architecture

- Bottom nav stays **Messages**. Inside `/inbox`, a two-segment control: **Messages | Avis**.
- URL-backed: `/inbox` (deliveries) vs `/inbox/avis` (family-feedback campaigns).
- The selector is full width, inherits `AppTheme.segmentedButtonTheme`, and must not show a selected check icon.
- Questionnaire is a **detail** of Messages (`/inbox/avis/:campaignId`), not a third inbox segment and not a Home archive.
- Accueil may ping an open campaign, then open `/inbox/avis` (or the questionnaire when there is exactly one open item).

### Child profile

- Entry is the **student context card** (avatar / name), not a sixth tab.
- Route `/child` is a **pushed page** on compact / medium and a **right drawer** on expanded. The last of the five primary tabs stays selected underneath.
- The page is the selected-child hub: identity, photo proposal, and leftover family papers (certificate, student ID, convocation, …) with print/download in place.

### Tab highlighting

The highlighted tab is always one of the five hubs. Pushed / drawer routes never clear the selection.

| Location family | Selected tab |
|-----------------|--------------|
| `/home…` | Accueil |
| `/calendar…`, `/session…`, `/attendance…` | Agenda |
| `/scolarite…`, `/grade…`, `/report-card…` | Scolarité |
| `/fees…` | Frais |
| `/inbox…` | Messages |
| `/account…`, `/settings…`, `/child…` | Last of the five (the hub stays mounted underneath) |

---

## 3. Routes (checkable inventory)

### Shell tabs (list / hub)

| Path | Screen |
|------|--------|
| `/login` | Connexion OTP (outside shell) |
| `/invite/:token` | Invitation accept (outside shell) |
| `/waiting` | Waiting for linked students (outside shell) |
| `/home` | Accueil |
| `/calendar` | Agenda |
| `/scolarite/notes` | Scolarité hub |
| `/fees` | Frais |
| `/inbox` | Messages |
| `/inbox/avis` | Avis / campagnes (same Messages tab) |

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
| `/inbox/avis/:campaignId` | Questionnaire avis | Messages |
| `/child` | Profil élève (photo + leftover papers) | last hub |
| `/account` | Compte | last hub |
| `/account/profile` | Profil | last hub (close returns to `/account`) |
| `/settings` | Paramètres | last hub (close returns to `/account`) |

Delivery ids (`delivery:v2:…`) include `:` and percent-encoded source keys (`%3A`). Navigate with `inboxMessagePath(id)` so GoRouter keeps the raw id, and load the row with POST `/one` (JSON body). GET `/message-deliveries/{id}` decodes `%3A` in the path and 404s for event notifications.

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

Hubs have **no brand app bar** and **no** EDAYA logo. Canvas background (`#F0F7FF`). Safe-area inset keeps the header cards below the status bar. **No** profile or help control on a toolbar or the navigation rail.

The EDAYA logo (`EdayaBrandLogo`) is for pre-auth chrome: native splash, Flutter bootstrap, login, invite, and waiting. It must not appear on the five hubs.

### Header cards

On the **five hubs**, the first chrome is a single header row:

- **Child card** (flex, remaining width) — `StudentContextCard`
- **Parent card** (square, photo only) — to the right of the child card; height matches the child card

Tapping the child avatar or name **pushes** `/child`. The expand control still opens the context sheet (student switcher). Tapping the parent card **pushes** `/account`. Compact / medium pushed pages do **not** repeat this header.

### Compact width (&lt; 600)

| Element | Requirement |
|---------|-------------|
| Primary nav | Bottom `NavigationBar` with the five destinations |
| App bar | None — no brand logo on hubs |
| Header | Child card + square parent photo card at the top of the hub (below the status bar) |

### Medium and wider (≥ 600)

| Element | Requirement |
|---------|-------------|
| Primary nav | Full-height `NavigationRail` (labels always visible) |
| App bar | None — no brand logo in the content column |
| Header | Same child + parent cards at the top of the content column |
| Rail trailing | Empty — no profile / help icons |

### Student context card

Must show, for the active student, **three left-aligned rows** beside the avatar:

1. Student name
2. School name
3. Class with school year (`6ème 1 · 2026 — 2027`)

Plus:

- Avatar (photo or initials) — opens `/child`
- Affordance to open the **context sheet** (student switcher)

Layout: one flex card in the header row (not a 2×2 grid).

### Parent account card

- Square `SurfaceCard` with `tint` = primary container (light blue).
- **No name and no email** — avatar / initials only.
- Sized to the child card height so the child card keeps the remaining width.
- Tooltip `Mon compte`. Tap opens `/account`.
- Initials come from the account / session display name (same source as the account overlay).

### Assistance

Assistance is a row on the **account overlay** (with Profil / Paramètres), not a shell chrome control. Do not document the in-app help SnackBar stub as a product feature (see §8).

### Context sheet

Opened from the student context card. Must contain:

1. **Mes enfants** — selectable linked students, grouped by school
2. **Année scolaire** — for each school group, a compact year control via overlay menu (`MenuAnchor`) placed beside the school name (not a separate full-width year section, and not an inline list of all years)

Year control must scale as historical years accumulate (scrollable menu; current year remains visible in the closed control). Different schools may have different selected years.

---

## 5. Adaptive breakpoints

| Tier | Width (logical px) | Chrome | Content |
|------|--------------------|--------|---------|
| Compact | &lt; 600 | Bottom navigation | Single column; details **push a full-screen page** (covers chrome) |
| Medium | ≥ 600 and &lt; 1000 | Navigation rail; no brand app bar | Max content width **840**; details push a full-screen page (no right drawer) |
| Expanded | ≥ 1000 | Rail + right overlay drawer | Detail over hub in the content column |

Constants (checkable):

| Name | Value |
|------|-------|
| Compact threshold | 600 |
| Expanded (drawer) threshold | 1000 |
| Max content width | 840 |

Prefer a single Agenda-style content column. Must **not** use a permanent side-by-side master–detail split pane.

---

## 6. List–detail presentation

The five tab hubs stay **mounted** (`IndexedStack`). Every non-hub route leaves the tab stack in place and opens as:

- **Compact / medium (&lt; 1000):** a **pushed full-screen page** covering the header cards and bottom nav / rail. Back returns to the hub.
- **Expanded (≥ 1000):** a **right drawer** over the hub; header cards and rail stay visible.

Applies to: Agenda, Scolarité, Frais, Messages (including Avis details), child profile, account, profile, and settings.

### Shell body vs pushed / drawer routes

| Kind | Paths |
|------|--------|
| Shell hubs (tab body) | `/home`, `/calendar`, `/scolarite/notes`, `/fees`, `/inbox`, `/inbox/avis` |
| Pushed page (compact/medium) or right drawer (expanded) | `/child`, `/account`, `/account/profile`, `/settings`, and every drill-down (session, attendance, programme, cahier, notes, bulletin, fee, payment, message, avis questionnaire) |

Home pings that switch **tabs** (`go('/fees')`) stay tab switches. Pings to `/child` or `/inbox/avis/:id` push (or open the drawer) on the current or target tab.

### Compact / medium (&lt; 1000)

- Hub stays mounted underneath (not disposed).
- Opening a detail **pushes a full-screen page** over the shell (no nested header cards, no bottom nav).
- Detail chrome is a back AppBar (`Retour`), not a close control and not an embedded strip under the child card.

### Expanded (≥ 1000)

- Hub remains full width in the content column under the drawer.
- Detail opens as a **right overlay drawer** over the hub (not over the header cards):
  - Default width fraction **0.4** of the host
  - Clamped roughly **360–520** dp and at most **50%** of host width
  - Scrim over the hub (~18% black); tap scrim dismisses (pop when possible, else `go(listPath)`)
  - Close control on the detail (×)
  - Drawer is not permanently split; when there is no selection, only the hub is shown

### Account and child

- `/child` and `/account` are pushed pages / drawer details, not extra tabs.
- `/account/profile` and `/settings` stack on `/account` (back returns to `/account`).
- Assistance lives on the account page, not in shell chrome.

### Print from the owning page

- **Frais** — receipt from a payment; invoice from a charge; account statement from the year summary.
- **Scolarité** — report card PDF from the bulletin detail.
- Leftover family papers without a domain page (schooling certificate, enrollment record, student ID, withdrawal certificate, convocation) live on `/child`.
- Do **not** list `receipt.v1` / `invoice.v1` / `account-statement.v1` / `report-card.v1` on a generic documents inbox.

### Home

- Home is a mounted hub like the other tabs (not a special chrome exception).
- Home attention pings (overdue fees, open campaign, photo/paper, bulletin, unread mail) then deep-link to the owning tab or push `/child`. Do not keep a campaign inbox on Home.

---

## 7. Checkable invariants (summary)

1. Exactly five primary FR labels: Accueil, Agenda, Scolarité, Frais, Messages.
2. Scolarité hub path is `/scolarite/notes`; no top Programme/Cahier/Notes/Bulletins tab bar.
3. Compact (&lt; 600): bottom nav; no brand app bar; child card + square parent photo card at the top of the hub.
4. ≥ 600: rail; no brand app bar; no profile / help on the rail.
5. ≥ 1000: right overlay detail drawer (~40%, scrim, close) over the hub; no permanent split.
6. Compact / medium: non-hub routes push a full-screen page (covers chrome and nav). Hubs stay mounted; one of the five tabs stays selected underneath.
7. Max unconstrained content width 840.
8. Header row visible on the five hubs (and behind the expanded drawer). Child avatar/name open `/child`; parent card opens `/account`.
9. Year selection only via menu overlay in the context sheet (per school, beside school name).
10. v1 is mostly read-only (profile contact / notification channels allowed); help/settings stubs must not be documented as product features (see §8).
11. Design-review (or equivalent) must cover **compact** (full-screen push), **medium** (rail, full-screen push), and **expanded** (rail + right drawer) widths.
12. No Documents destination. Print from Frais / Scolarité / child leftover papers.
13. Inbox has exactly two URL-backed lists: `/inbox` and `/inbox/avis`.
14. Unauthenticated users land on `/login`; invite/waiting stay outside the five tabs; authenticated users with linked children land on `/home`.

---

## 8. Non-normative

Must not be treated as shell requirements:

- A `ShellContextBar` with student chip left + guardian chip right as the primary header model
- Scolarité top sub-tabs (Programme / Cahier / Notes / Bulletins)
- A dedicated Documents menu or issuance dump as a product surface
- Help centre implemented as a SnackBar stub
- Settings controls that are no-ops (dark mode, language) presented as finished product behavior
- Triple paint-path implementation details for the app bar (Scaffold vs chrome wrappers) — only the UX outcomes in §4–§6 are normative
- Deprecated “permanent master–detail” naming or APIs
- Historical redesign tables comparing old production screens
- Web staff patterns (list + URL drawer + mutation modals as the workspace model)

## Guardian conversations

Messages supports New message, a merged notification/conversation list, and `/inbox/conversation/:conversationId` details under the existing Messages tab. Avis remains unchanged. Teacher conversations capture the selected child and a currently assigned teacher; school conversations may omit the child. Subject and body are text only. Recipient changes clear composer fields. Unsent drafts remain transient and are cleared on profile/logout changes.

Conversation details retain their captured school, participants and child independently of the shell selection. Guardians retain authorized read-only history after the original teaching relationship ends. Teacher exchanges explain school oversight. School enquiry status is shown separately from personal unread state. Push destinations establish the correct selected school/profile before navigation, including after sign-in.

## Separate Guardian v2 implementation

The child-first Home and unified results workspace is implemented in `apps/guardian_v2`. Its normative contract is [Guardian v2 workspace](guardian-v2-workspace-spec.md). This document continues to describe the original `apps/guardian` shell.
