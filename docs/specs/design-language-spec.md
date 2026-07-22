# Edaya Mobile — Guardian Design Language Spec

> **Applies to:** Guardian mobile experience (`apps/guardian_prototype` in Phase 2; `apps/guardian` + `edaya_shared` in Phase 3)

This document defines the visual design language for the Edaya Guardian app. It is the normative reference for the standalone prototype and future production integration.

---

## 1. Brand character

Edaya Guardian is a **family companion** for school life — not a staff data terminal.

| Trait | Expression |
|-------|------------|
| **Warm & approachable** | Rounded geometry, soft shadows, Galak Round brand voice |
| **Action-oriented** | Home surfaces what needs attention; CTAs are obvious |
| **Trustworthy** | Clear official vs provisional labels; calm error states |
| **Child-aware** | Student context always visible when content is child-specific |
| **Bilingual-ready** | French-first copy; short nav labels for 390px phones |

**Palette (brand):**

| Token | Hex | Role |
|-------|-----|------|
| `primary` | `#2563EB` | Actions, active nav, links |
| `primaryLight` | `#60A5FA` | Progress fills, secondary accents |
| `accent` | `#FBBF24` | Highlights, attention accents |
| `background` | `#F0F7FF` | Scaffold canvas |
| `onBackground` | `#1E293B` | Primary text |

**Semantic colors:**

| State | Background | Foreground |
|-------|------------|------------|
| Success | `#DBEAFE` | `#1E293B` |
| Warning / pending | `#FEF3C7` | `#92400E` |
| Error / overdue | `#FEE2E2` | `#7F1D1D` |
| Neutral | `#F1F5F9` | `#64748B` |
| Unread | `#DBEAFE` | `#2563EB` |

---

## 2. Typography

Two-tier system — Galak Round Demo is **display only** (single weight, personal-use license).

| Role | Font family | Usage |
|------|-------------|-------|
| Brand wordmark | `GalakRound` | Login logo, app title |
| Display / headline | `GalakRound` | Screen heroes, large numbers |
| Title / body / label | `Nunito` | UI copy, nav, buttons, lists |

| Style | Family | Size | Weight |
|-------|--------|------|--------|
| `displaySmall` | Galak | 32 | regular |
| `headlineMedium` | Galak | 24 | regular |
| `headlineSmall` | Galak | 20 | regular |
| `titleLarge` | Nunito | 18 | 600 |
| `titleMedium` | Nunito | 16 | 600 |
| `bodyLarge` | Nunito | 16 | 400 |
| `bodyMedium` | Nunito | 14 | 400 |
| `bodySmall` | Nunito | 12 | 400 |
| `labelLarge` | Nunito | 14 | 600 |
| `labelSmall` | Nunito | 11 | 500 |

Do **not** apply fake bold to Galak. Use Nunito for weight variation.

---

## 3. Spacing, radii, elevation

**Spacing (4pt grid):** 4, 8, 12, 16, 20, 24, 32

| Token | Value | Usage |
|-------|-------|-------|
| `screenPadding` | 16 | Horizontal screen gutters |
| `cardPadding` | 16 | Inside cards |
| `sectionGap` | 24 | Between sections |
| `listGap` | 8 | Between list rows |

**Radii:**

| Token | Value | Usage |
|-------|-------|-------|
| `sm` | 12 | Inputs, chips |
| `md` | 16 | Cards |
| `lg` | 20 | Attention cards, sheets |
| `pill` | 999 | Badges, nav indicator |

**Elevation:** Borderless cards use soft shadow only — **no stroke, no `outlineVariant` border**.

```dart
BoxShadow(color: Color(0x141E293B), blurRadius: 12, offset: Offset(0, 4))
```

### Card specification (normative)

Guardian surfaces are **borderless** by default. Separation comes from the `#F0F7FF` canvas, white fill, and elevation — not from gray outlines.

| Property | Value | Notes |
|----------|-------|-------|
| **Border** | None | Do not use `BorderSide`, `outline`, or `Card` default outline |
| **Fill** | `#FFFFFF` (`surface`) | Optional tint for unread/attention states |
| **Radius** | `16` (`md`) | `20` (`lg`) for hero / attention blocks |
| **Padding** | `16` | Consistent inner spacing |
| **Elevation** | Soft shadow (see above) | `elevation: 0` on `Material`; shadow via `BoxDecoration` |
| **Gap between cards** | `8` | Vertical list spacing |

**Use borderless cards for:** list rows, fee summary, session tiles, inbox items, header chips (student / guardian), settings groups, login form container.

**Keep borders for:** text fields, segmented controls, and dividers inside a card — not around the card itself.

**Do not use:** Flutter `Card` with `side: BorderSide(...)`, production guardian’s outlined `Card` + `ListTile` pattern.

**Variants:**

| Variant | Fill | Border | Shadow |
|---------|------|--------|--------|
| `SurfaceCard` | White | None | Yes |
| `AttentionCard` | `primaryContainer` | None | Yes (primary-tinted) |
| `ListRow` | White (via `SurfaceCard`) | None | Yes |
| Unread row | `primaryContainer` @ 35% | None | Yes |
| Header chip | White | None | Yes |

```dart
// Canonical borderless card decoration
BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Color(0x141E293B),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ],
)
```

---

## 4. Information architecture

### Bottom navigation (5 tabs)

| Tab | FR | EN |
|-----|----|----|
| Home | Accueil | Home |
| Calendar | Agenda | Calendar |
| Schooling | Scolarité | Schooling |
| Fees | Frais | Fees |
| Messages | Messages | Messages |

### Scolarité sub-tabs (top tab bar)

| Tab | FR |
|-----|-----|
| Programme | Programme |
| Cahier | Cahier |
| Notes | Notes |
| Bulletins | Bulletins |

### Global header (`ShellContextBar`)

Single row:

- **Left (expanded):** Student chip — avatar, name, class, chevron → opens context sheet
- **Right:** Guardian profile chip — avatar + first name → opens account

### Context sheet (student + year)

Opened from the student chip. Contains:

1. **Mes enfants** — selectable list (typically few linked students)
2. **Année scolaire** — compact dropdown control (same `TextButton` + chevron + label as the former header picker), **not** an inline list of all years

The year control uses a scrollable `MenuAnchor` menu so it scales as historical years accumulate. Current year stays visible; the full list appears only on demand.

---

## 5. Components

### Cards (see [Card specification](#card-specification-normative))

All content containers follow the borderless card rules unless noted otherwise.

### `SurfaceCard`

Borderless white card: 16px radius, soft shadow, 16px padding. **No outline.**

### `AttentionCard`

Borderless primary-tinted surface for urgent items (overdue fee, unread message, absence). Title + subtitle + primary CTA. Shadow only — no border.

### `SummaryMetric`

Label (small, muted) + value (title weight). Used inside borderless cards (fee summary grids).

### `ListRow`

Borderless `SurfaceCard` wrapper: leading icon/avatar in tinted circle, title + subtitle, optional trailing value/chevron, optional `StatusChip`.

### `AcademicYearPicker`

Compact `TextButton` + label + chevron. Opens a scrollable overlay menu (`MenuAnchor`) — not an inline year list. Placed in the context sheet; scales to many historical years.

### `ShellContextBar`

Single-row header: borderless student chip (left) + borderless guardian chip (right).

### `StatusChip`

Pill badge with semantic background. Always paired with text label (never color alone). Not a card — no shadow required.

### `SectionHeader`

`titleMedium` + optional trailing text action. Not a card.

### `EmptyState` / `ErrorState`

Centered icon, title, body, optional retry/action button. No card wrapper unless grouping multiple actions.

### `ProgressBar`

8px height, `primaryLight` track, `primary` fill, rounded caps.

---

## 6. Accessibility

- Minimum touch target: 48×48 dp
- Contrast: primary on white ≥ 4.5:1 for body text
- Status: icon + label + color
- Support 200% text scale without clipping nav labels (use short FR strings)
- Respect `MediaQuery.disableAnimations`

---

## 7. Per-screen visual direction

Baseline “before” screenshots: `apps/guardian/design-review/phone-fr/`

| # | Screen | Current problems | Target |
|---|--------|------------------|--------|
| 00 | Login | Dev copy, plain form, no brand | Centered Galak wordmark, welcome card, polished inputs, no dev UI in prototype |
| 01 | Home (new) | N/A | Attention card, today timeline, fee/grade/message snippets |
| 02 | Calendar | Flat session cards, busy header | Week chips, subject-accent session tiles, slim context header |
| 03 | Events | Same as calendar | Event tiles with date badge |
| 04 | Attendance | Plain list | Status chips, lighter rows |
| 05 | Session details | Basic sheet | Section blocks, attendance badge, logbook typography |
| 06 | Programme | Thin progress bars | Accent progress, topic cards with status chips |
| 07 | Cahier | Plain list | Logbook entries with date/subject hierarchy |
| 08 | Notes | Segmented + dense | Period picker chips, grade cards with score emphasis |
| 09 | Bulletins | Plain tiles | Report card rows with period + status |
| 10 | Grade details | Minimal modal | Score hero, coefficient, provisional label |
| 11 | Report card | Text-heavy | Structured sections, download CTA placeholder |
| 12 | Fees | Flat summary card | Hero metrics, overdue emphasis, payment rows |
| 13 | Payment details | Basic | Receipt-style layout |
| 14 | Inbox | Uniform cards | Unread accent bar, envelope in tinted circle |
| 15 | Message details | Plain | Readable body, metadata chips |
| 16 | Settings | Default list | Grouped sections, Galak section titles |
| 17 | Account | Basic sheet | Profile card, sign-out prominence |
| 18 | Profile | Form fields | Clean grouped form |
| 19 | My students | Plain list | Selected row highlight, avatar |
| 20 | Year picker | Plain list | Compact dropdown in context sheet; scrollable menu for many years |

---

## 8. Font licensing

| Font | License | Production |
|------|---------|------------|
| Galak Round Demo | Personal use (Befonts) | Acquire commercial license before store release |
| Nunito Variable | SIL OFL | Production-safe |

---

## 9. Phase mapping

| Phase | Deliverable |
|-------|-------------|
| 1 | This spec + per-screen table |
| 2 | `apps/guardian_prototype` — runnable mock app |
| 3 | Port `lib/design/` → `edaya_shared`; wire `apps/guardian` API |

See `docs/plans/guardian-phase3-migration.md` for production integration checklist.
