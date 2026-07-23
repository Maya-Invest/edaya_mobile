# Guardian Shared Components Spec

> **Applies to:** Guardian Flutter app  
> **Audience:** Implementers and agents  
> **Authority:** This document is normative. Implementations must be cross-checked against it.

This spec defines the shared UI component and layout-primitive contracts for the Guardian family companion. Visual tokens (hex, type scale, card shadow) follow the design-language rules; this file names widgets, parameters, and behavioral contracts only.

Component type names below match the current design-system identifiers for 1:1 cross-check.

---

## 1. Layout primitives

### Breakpoints

| Constant | Value (logical px) | Effect |
|----------|--------------------|--------|
| Compact threshold | 600 | Bottom nav → navigation rail |
| Expanded threshold | 1000 | List detail → right overlay drawer |
| Max content width | 840 | Cap for unconstrained main column |

Helpers must expose: whether to use the rail, whether to use the detail drawer, and whether the detail drawer is active for the current width.

### `AdaptiveContent`

| Param | Required | Contract |
|-------|----------|----------|
| `child` | yes | Content to lay out |
| `constrain` | no (default true) | When true, center and cap width at `maxWidth` |
| `maxWidth` | no (default 840) | Maximum content width |

When the parent width is ≤ `maxWidth`, child fills the parent. When wider, child is top-centered at `maxWidth`.

### Shell chrome inheritance

| Type | Role |
|------|------|
| `ShellChrome` | Provides `showHeader`, `header` (student context), optional `appBar` for medium+ content column |
| `ShellChromeBody` | Paints optional app bar + header above page body (e.g. Accueil) |
| `ShellChromeDrawerMaster` | Paints header above list master when not using the expanded drawer stack |
| `DetailDrawerMasterColumn` | Paints optional app bar + header + master so the overlay can cover title → bottom |

UX outcomes for chrome placement are defined by the shell contract; implementations must preserve those outcomes.

### `ListDetailHost`

| Param | Required | Contract |
|-------|----------|----------|
| `listPath` | yes | Path when dismissing detail / drawer |
| `master` | yes | List or hub page |
| `detailChild` | yes | Nested detail route child |
| `isListPath` | no | Override list detection (default: path equals `listPath`) |

Behavior:

- Width &lt; 1000: if list path → master under chrome header; else → detail fills body.
- Width ≥ 1000: `DetailDrawerScaffold` with master column (app bar + header + master) and overlay detail when not on list path.

### `DetailDrawerScaffold`

| Param | Required | Contract |
|-------|----------|----------|
| `master` | yes | Full-bleed master |
| `detail` | yes | Overlay child |
| `hasSelection` | yes | When false, show master only |
| `listPath` | yes | Scrim / dismiss target |
| `widthFraction` | no (default 0.4) | Target fraction of host width |

Drawer width must clamp to approximately **360–520** dp and at most **50%** of host width. Scrim ~18% black, opaque tap target. Drawer material uses canvas background, elevation ~12, square corners (no rounded panel).

---

## 2. Surfaces and lists

### `SurfaceCard`

| Param | Required | Contract |
|-------|----------|----------|
| `child` | yes | Content |
| `padding` | no (default 16 all) | Inner padding |
| `onTap` | no | Makes card tappable |
| `tint` | no | Fill override; default white surface |

Must be borderless: radius 16, soft card shadow, no outline. Optional tint for attention / unread / selected states. Default padding is 16; callers may override for denser chrome (e.g. `StudentContextCard`).

### `ListRow`

| Param | Required | Contract |
|-------|----------|----------|
| `title` | yes | Primary line |
| `subtitle` | no | Secondary line |
| `leading` | no | Icon / avatar |
| `trailing` | no | Value / chevron / custom |
| `badge` | no | Label for `StatusChip` |
| `badgeTone` | no | Chip tone; default `info` when unread else `neutral` |
| `onTap` | no | Row action |
| `unread` | no (default false) | Tint `primaryContainer` @ 35% |
| `selected` | no (default false) | Tint `primaryContainer` @ 55% (wins over unread) |
| `tint` | no | Explicit fill override |

Built on `SurfaceCard`. Selected and unread must not require a stroke.

### `AttentionCard`

Compact home CTA row. **One layout for all tones** — icon well · title · subtitle · chevron. No hero block, no full-width filled button, no “Action requise” banner variant.

| Param | Required | Contract |
|-------|----------|----------|
| `title` | yes | Title |
| `subtitle` | yes | Supporting line |
| `icon` | yes | Leading icon |
| `tone` | yes | `important` \| `normal` \| `message` |
| `onTap` | no | Navigation |

| Tone | Surface fill | Icon well | Icon / title color |
|------|--------------|-----------|--------------------|
| `important` | `errorContainer` @ ~55% | white | `error` |
| `normal` | `primaryContainer` | white | `primary` (title default) |
| `message` | white | `primaryContainer` | `primary` |

### `StatusChip`

| Param | Required | Contract |
|-------|----------|----------|
| `label` | yes | Visible text (never color alone) |
| `tone` | no (default `neutral`) | Semantic tone |
| `icon` | no | Overrides default tone icon |

Pill radius; horizontal padding ~10, vertical ~4. Always shows **icon + label + color** (default icon per tone). Tone colors follow the design-language semantic chip table.

### `SectionHeader`

| Param | Required | Contract |
|-------|----------|----------|
| `title` | yes | Section title (`titleMedium`) |
| `action` | no | Trailing text-button label |
| `onAction` | no | Trailing action |

Not a card. Bottom padding ~12 before section content.

### `SummaryMetric`

| Param | Required | Contract |
|-------|----------|----------|
| `label` | yes | Muted small label |
| `value` | yes | Emphasized value |
| `valueColor` | no | Optional value color (e.g. overdue) |

Used inside cards (fee summary grids). Not a card by itself.

### `EmptyState`

| Param | Required | Contract |
|-------|----------|----------|
| `title` | yes | Primary empty message |
| `message` | no | Supporting copy |
| `actionLabel` | no | Optional filled button label |
| `onAction` | no | Button handler |

Centered icon + title + optional body + optional action. No card wrapper required.

### `PersonAvatar`

| Param | Required | Contract |
|-------|----------|----------|
| `initials` | yes | Fallback letters |
| `radius` | no (default 20) | Circle radius |
| `photoUrl` | no | Network photo; fall back to initials on failure |

Initials avatar: primary fill, white Nunito semibold text.

### `StudentContextCard`

| Param | Required | Contract |
|-------|----------|----------|
| `studentName` | yes | Active student |
| `studentInitials` | yes | Avatar fallback |
| `classLabel` | yes | Class |
| `schoolName` | yes | School |
| `schoolYear` | yes | Year label shown in school column |
| `photoUrl` | no | Student photo |
| `onSelectStudent` | no | Opens context sheet |

Borderless card; dual columns student | school; chevron affordance when selectable. May use tighter-than-default `SurfaceCard` padding.

### `AcademicYearPicker`

| Param | Required | Contract |
|-------|----------|----------|
| `selectedYear` | yes | Closed-control label |
| `years` | yes | Menu items |
| `onSelected` | yes | Selection callback |

Must use an overlay menu (`MenuAnchor`), not an inline list of all years. Selected year may show a check in the menu. Menu max size roughly 280 × 320.

### `PrototypeAppBar`

| Param | Required | Contract |
|-------|----------|----------|
| `onProfileTap` | no | When null, omit profile control |
| `onHelpTap` | no | When null, omit help control |

Centered `edaya` wordmark. Preferred size = standard toolbar height. Canvas background, no surface tint.

### `PrototypeDetailScaffold`

| Param | Required | Contract |
|-------|----------|----------|
| `body` | yes | Detail content |
| `title` / `titleWidget` | one | Header label |
| `fallbackRoute` | no (default `/home`) | If cannot pop |
| `embedded` | no (default false) | Drawer mode |

| `embedded` | Chrome |
|------------|--------|
| false | Scaffold with back affordance |
| true | Column with title + **close** (×); no system back in the header |

Dismiss must **pop when possible**, else navigate to `fallbackRoute`. Scrim on the list–detail host may instead `go(listPath)`; both patterns are allowed.

### `PrototypeProgressBar`

| Param | Required | Contract |
|-------|----------|----------|
| `value` | yes | Progress in `[0, 1]` (clamped) |

Height 8; track `primaryContainer`; fill `primary`; pill caps.

---

## 3. Domain presentation widgets

Contracts describe **presentation props**. Implementations must not freeze shared widgets to mock-store types in the long term; cross-check may accept current typed props until domain models are injected.

### `TimetableSummaryCard`

| Param | Required | Contract |
|-------|----------|----------|
| Day summary data | yes | Counts or empty state for lessons / activities / assessments |
| `onTap` | no | Navigate to agenda / day |

Shows title “Emploi du temps”, status chips for non-empty counts, chevron when tappable. Borderless `SurfaceCard`.

### `NoSchoolDayBanner`

| Param | Required | Contract |
|-------|----------|----------|
| Event title / description / kind | yes | No-school day payload |

Error-tinted borderless card; “Pas d’école” title; kind as error `StatusChip`.

### `SchoolEventRow`

| Param | Required | Contract |
|-------|----------|----------|
| Event fields | yes | Title, date, kind |

Borderless list-style row for a school event (not a session).

### Session category visuals

Categories: **lesson**, **activity**, **assessment**.

| Category | Background token | Icon meaning |
|----------|------------------|--------------|
| lesson | `primaryContainer` | Book / lesson |
| activity | `successContainer` | Activity |
| assessment | `accentContainer` | Assessment |

`SessionCategoryIcon` wraps icon in a rounded well (default icon size 20, padding 8). Icon hue may use category accent colors; backgrounds must use the token fills above.

---

## 4. Usage rules

1. Prefer `ListRow` / `SurfaceCard` for tappable list content — not raw outlined `Card` + `ListTile` as the default pattern.
2. Prefer `AttentionCard` for Accueil attention items — do not invent a second hero CTA layout.
3. Prefer `EmptyState` for empty lists; do not require a separate shared `ErrorState` widget unless this spec is extended.
4. Prefer `StatusChip` + label for status; never color alone.
5. Prefer `AcademicYearPicker` overlay menu for year selection in the context sheet.
6. Prefer `PrototypeDetailScaffold` for detail routes so embedded vs full-body chrome stays consistent.
7. Prefer `AdaptiveContent` for scrollable page bodies that should respect max content width 840.

---

## 5. Checkable invariants (summary)

1. `SurfaceCard` / `ListRow` / `AttentionCard`: borderless, radius 16, soft shadow.
2. `AttentionCard` tones are exactly `important` / `normal` / `message` with fills in §2; no hero button variant.
3. `ListRow` unread tint 35% and selected tint 55% of `primaryContainer`.
4. `PrototypeProgressBar`: height 8, track `primaryContainer`, fill `primary`.
5. `DetailDrawerScaffold` default fraction 0.4 with width clamp 360–520 / ≤50%.
6. `AcademicYearPicker` uses menu overlay, not inline year list.
7. `PrototypeDetailScaffold(embedded: true)` shows close, not back.
8. `AdaptiveContent` default max width 840.
9. No required shared `ErrorState` or `ShellContextBar` component.
10. Shared presentation widgets must not depend on mock domain types as a permanent contract.

---

## 6. Non-normative

Must not be treated as shared-component requirements:

- `ErrorState` as a required shared widget
- `ShellContextBar` as a shared header widget
- Fees-only private widgets (amount trailers, installment cards) until explicitly promoted here
- Account screens built with raw `ListTile` instead of `ListRow` (inconsistency, not a pattern)
- Calendar week-selector magic font sizes (9 / 10 / 12) as a shared type scale
- Untokenized copy-pasted icon wells and raw Material `Colors.*` / ad-hoc hex as the icon-well system
- Deprecated master-detail aliases
- A specific Dart barrel / import path (only the public contracts above are normative)
- Coupling shared widgets permanently to mock-store model types
