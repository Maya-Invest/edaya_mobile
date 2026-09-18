# Design Language Spec

> **Applies to:** Guardian Flutter app and Teacher UI prototype (`apps/teacher_prototype`)  
> **Audience:** Implementers and agents  
> **Authority:** This document is normative. Implementations must be cross-checked against it.

This spec defines the visual design language shared by the Guardian family companion and the Teacher Accueil-first prototype: brand, color, type, spacing, elevation, cards, and accessibility. Navigation and shell chrome are defined in [guardian-shell-spec.md](guardian-shell-spec.md) and [teacher-shell-spec.md](teacher-shell-spec.md).

Visual tokens follow **EDAYA 1.0.0** (`packages/edaya_shared/design-system/tokens.json`, `AppTheme`, `EdayaColors`, `EdayaTypography`, `EdayaBrandLogo`). Accueil shell IA (five tabs, overlays, borderless cards) stays in the shell specs.

---

## 1. Brand character

Guardian is a **family companion** for school life — not a staff data terminal.

| Trait | Expression |
|-------|------------|
| Warm and approachable | Rounded geometry, soft shadows, Poppins headings / Inter UI |
| Action-oriented | Home surfaces what needs attention; CTAs are obvious |
| Trustworthy | Clear official vs provisional labels; calm empty states |
| Child-aware | Student context always visible when content is child-specific |
| Bilingual-ready | French-first copy; short nav labels for 390 px phones |

The supplied outlined EDAYA logos are the wordmark. Never reconstruct `edaya` in UI type.

---

## 2. Palette

### Brand tokens

| Token | Hex | Role |
|-------|-----|------|
| `primary` | `#2563EB` | Actions, active nav, links, avatar fill |
| `primaryLight` | `#60A5FA` | Secondary accents only (not progress track) |
| `accent` | `#FBBF24` | Highlights |
| `background` | `#F0F7FF` | Scaffold / canvas |
| `onBackground` | `#1E293B` | Primary text |
| `primaryContainer` | `#DBEAFE` | Soft primary fill (chips, selected/unread tint base, progress track) |
| `successContainer` | `#F0FDF4` | Green fill for session/category accents where green is intentional |
| `accentContainer` | `#FEF3C7` | Warning / pending fill |
| `errorContainer` | `#FEF2F2` | Error / overdue fill |
| `onErrorContainer` | `#B91C1C` | Text on error fill |
| `onSurfaceVariant` | `#5B6B82` | Secondary / muted text |
| `outlineVariant` | `#E2E8F0` | Dividers and input borders only — never card chrome |
| `surface` | `#FFFFFF` | Card fill |
| `error` | `#B91C1C` | Error icon / emphatic error title |
| `segmentUnselected` | `#EFF6FF` | Unselected segmented-control fill (`surfaceContainerHighest`) |

### Semantic chip tones

Status chips and badges must use this mapping (background / foreground):

| Tone | Background | Foreground |
|------|------------|------------|
| `neutral` | `#F1F5F9` | `#5B6B82` |
| `info` | `#DBEAFE` | `#2563EB` |
| `success` | `#DBEAFE` | `#1E293B` |
| `warning` | `#FEF3C7` | `#92400E` |
| `error` | `#FEF2F2` | `#B91C1C` |

`success` chip fill is primary-container blue (not `successContainer` green). Green `successContainer` is reserved for non-chip accents (for example session category backgrounds) and must not redefine the `success` chip tone without a spec change.

Unread emphasis on list rows uses `primaryContainer` at **35%** opacity. Selected list rows use `primaryContainer` at **55%** opacity.

---

## 3. Typography

Bundled, offline fonts. Logos are artwork, never UI text.

| Role | Family | Usage |
|------|--------|-------|
| Brand | EDAYA outlined logo PNG (`EdayaBrandLogo`) | Splash, bootstrap, login, invite, waiting |
| Display / headline | Poppins (600) | Screen heroes, large numbers, section titles |
| Title / body / label | Inter | UI copy, nav, buttons, lists, numeric data |

| Style | Family | Size (sp) | Weight |
|-------|--------|-----------|--------|
| `displaySmall` | Poppins | 28 | 600 |
| `headlineMedium` | Poppins | 24 | 600 |
| `headlineSmall` | Poppins | 24 | 600 |
| `titleLarge` | Poppins | 20 | 600 |
| `titleMedium` | Inter | 16 | 600 |
| `titleSmall` | Inter | 14 | 600 |
| `bodyLarge` | Inter | 16 | 400 |
| `bodyMedium` | Inter | 14 | 400 |
| `bodySmall` | Inter | 12 | 400 |
| `labelLarge` | Inter | 14 | 600 |
| `labelSmall` | Inter | 12 | 500 |

Minimum logo widths: vertical 88, horizontal 128, symbol 32. Vertical artwork on splash, bootstrap, login, invite, and waiting. Do not place the logo on authenticated hub chrome.

---

## 4. Spacing, radii, elevation

### Spacing (4 pt grid)

| Token | Value (dp) | Typical use |
|-------|------------|-------------|
| `xxs` | 4 | Tight gaps inside rows |
| `xs` | 8 | List gap between cards |
| `sm` | 12 | Icon-to-text gap |
| `md` | 16 | Screen gutter, card padding |
| `lg` | 20 | Larger inner padding |
| `xl` | 24 | Section gap |
| `xxl` | 32 | Sparse vertical rhythm |

Normative aliases:

| Alias | Value |
|-------|-------|
| `screenPadding` | 16 |
| `cardPadding` | 16 |
| `sectionGap` | 24 |
| `listGap` | 8 |

### Radii

| Token | Value (dp) | Usage |
|-------|------------|-------|
| `sm` | 12 | Inputs, small wells |
| `md` | 16 | All content cards |
| `lg` | 20 | Sheets / large containers (not default cards) |
| `pill` | 999 | Chips, progress caps, nav indicator |

### Elevation

Borderless cards use soft shadow only — **no stroke**, no `outlineVariant` border around the card.

```
BoxShadow(color: #141E293B, blurRadius: 12, offset: (0, 4))
```

Material elevation on the card itself must be **0**; shadow is applied via decoration.

---

## 5. Card specification (normative)

Guardian surfaces are **borderless** by default. Separation comes from the `#F0F7FF` canvas, white (or tinted) fill, and elevation — not from gray outlines.

| Property | Value | Notes |
|----------|-------|-------|
| Border | None | No `BorderSide` / outline on card chrome |
| Fill | `#FFFFFF` (`surface`) | Optional tint for unread / attention / selected |
| Radius | 16 (`md`) | Default for all content cards |
| Padding | 16 default | Call sites may override (e.g. denser shell chrome cards) |
| Elevation | Soft shadow above | See §4 |
| Gap between cards | 8 | Vertical list spacing |

**Must use borderless cards for:** list rows, fee summary blocks, session tiles, inbox items, student context card, settings groups, login form container, attention rows.

**May keep borders for:** text fields, segmented controls, and dividers **inside** a card — not around the card.

Segmented controls inherit `AppTheme.segmentedButtonTheme`: selected fill `primary` with `onPrimary` label; unselected fill `#EFF6FF` with navy label. The Messages/Avis control is full width and must not show a selected check icon.

**Must not use:** outlined Material `Card` with a stroke as the default content container.

### Progress bar

| Property | Value |
|----------|-------|
| Height | 8 dp |
| Track | `primaryContainer` (`#DBEAFE`) |
| Fill | `primary` (`#2563EB`) |
| Caps | Pill radius |
| Value | Clamped to `[0, 1]` |

---

## 6. Accessibility

| Rule | Requirement |
|------|-------------|
| Touch target | Minimum **48 × 48** dp for interactive controls |
| Contrast | Primary text on white ≥ **4.5:1** |
| Status | Always **icon + label + color** (never color alone) |
| Text scale | See **Text scale** below |
| Motion | See **Reduced motion** below |

### Text scale (200%)

The UI must remain usable when the platform text scale factor is **2.0** (200%).

**Must:**

- Keep primary nav labels short enough that all five FR destinations remain readable without truncation that hides meaning at 200% on a **390** logical-px width.
- Prefer wrapping or ellipsis on secondary lines over overlapping controls.
- Keep touch targets at least 48×48 even when labels grow (do not shrink hit areas to fit larger type).
- Avoid fixed-height text boxes that clip body copy at 200%.

**Must not:**

- Rely on tiny custom font sizes (e.g. 9–10 sp) for essential labels in chrome or primary lists.
- Use layout that assumes single-line nav labels at default scale only.

**Verification:** Manual QA on device/OS large-text settings before release. Automated text-scale pumps are not required for now.

### Reduced motion

When `MediaQuery.disableAnimations` is **true** (or the platform equivalent for reduced motion):

**Must:**

- Skip or replace non-essential motion (decorative transitions, staggered entrances, looping indicators that are purely ornamental).
- Keep functional feedback that is not animation-dependent (color, icons, text, progress values).

**Must not:**

- Gate critical information exclusively behind an animation that never completes when animations are disabled.
- Introduce custom controllers that ignore `disableAnimations` / reduced-motion flags.

When the app has no custom animations, compliance is vacuous but the rule still applies as soon as motion is added.

**Verification:** Manual QA with the platform reduced-motion / disable-animations setting before release. Automated reduced-motion tests are not required for now.

---

## 7. Font licensing

| Font | Constraint |
|------|------------|
| Inter | Production-safe (SIL OFL); bundled in `edaya_shared` |
| Poppins Semibold | Production-safe (SIL OFL); headings only, never a typed wordmark |
| EDAYA outlined logos | Supplied artwork; PNG derivatives in `edaya_shared/assets/brand/` |

---

## 8. Non-normative

The following must **not** be treated as design-language requirements:

- Historical “before → after” production redesign tables
- Phase / migration narratives that treat a prototype as the source of truth
- Untokenized icon wells (ad-hoc padding 8 + radius 10) and raw Material `Colors.*` or one-off hex fills outside the palette tables above
- Shipping Galak Round Demo (or any personal-use-only display font) in the app binary
- Reconstructing the EDAYA wordmark as UI text (`Text('edaya')`)
- Redefining chip `success` as green `successContainer` without changing §2
- Card radius `lg` (20) as the default for attention or list cards (default remains `md` 16)
- Progress track colored with `primaryLight` instead of `primaryContainer`
