# EDAYA mobile design language

Normative. Applies only to `apps/guardian`, `apps/teacher`, and presentation code in `packages/edaya_shared`. Current source defines scope. Do not restore removed apps, prototype layouts or their navigation. Backend, generated API clients, signing configuration, identifiers and business logic remain outside UI changes.

## Visual foundations — version 1.0.0

EDAYA should feel calm, trustworthy, and carefully finished. Staff, teachers, and families should recognize one brand while retaining interfaces suited to their daily tasks. Improve clarity through hierarchy, typography, spacing, and consistent feedback; preserve familiar workflows and effective components.

| Role | Light value | Application |
|---|---|---|
| Primary | `#2563EB` | Actions, links, selection; hover `#1D4ED8` |
| Supporting sky | `#60A5FA` | Decoration, never small text on white |
| Amber | `#FBBF24` | Restrained decoration, under 10% of visible surface; navy foreground |
| Canvas / surface | `#F0F7FF` / `#FFFFFF` | Sky canvas, white cards and chrome |
| Text / secondary | `#1E293B` / `#64748B` | Titles/data and supporting labels |
| Separator / control outline | `#E2E8F0` / `#64748B` | Subtle structure; identifiable inputs |
| Success | `#15803D` on `#F0FDF4` | Confirmed success, with a label/icon |
| Warning | `#92400E` on `#FEF3C7` | Pending or caution, with a label/icon |
| Danger | `#B91C1C` on `#FEF2F2` | Error, overdue, destructive actions |
| Information | `#1D4ED8` on `#E0F2FE` | Informational states |

The base slate remains `#64748B`; the shared secondary-text role uses `#5B6B82` so small text also meets contrast on the sky canvas (the base slate measures only 4.41:1 there).

Poppins Semibold is for headings; Inter Regular/Medium/Semibold/Bold is for body, labels, buttons, tables, and all numerical data. Load fonts from bundled files with their OFL licenses. Never request fonts from a third-party server at runtime. Use tabular figures for aligned amounts and scores. Use 28px web page titles, 24 logical pixels mobile page titles, 20 section titles, 16 card titles, 14–16 body, and 12 supporting labels. Heading line-height is about 1.3; body 1.5–1.6. Support wrapping and enlargement; do not shrink important values to fit.

Use the 4/8/12/16/24/32/48 spacing scale. Retain established rounded primitives: 12 controls, 14 base, 16 cards, 24 overlays. Keep shadows restrained and neutral. Useful existing motion stays, with reduced-motion support; avoid decorative perpetual animation.

## Artwork

The supplied outlined EDAYA logos are authoritative artwork. Never reconstruct the wordmark using text or substitute an academic icon for the product logo. Use vertical artwork in spacious sign-in areas, horizontal artwork in headers/sidebar areas, and symbols only in compact contexts already identified as EDAYA. Minimum rendered artwork widths: vertical 88, horizontal 128, symbol 32. The wrapper reserves clear space; do not crop its padding. Favicons alone may use the symbol at platform-required 16/24/32px. No recoloring, stretching, shadows on the artwork, or text laid over it. White artwork belongs on a dark or royal-blue surface.

## Accessibility and preserved behavior

Preserve every existing destination, field, data item, control, permission condition, validation rule, loading signal, and action result. UI-only work must not change authentication clients, controllers, API payloads, redirects, route contracts, session handling, grants, business rules, or calculations. A visual limitation is not authorization for a new feature. Keep recognizable operational icons and native platform behaviors.

Target WCAG AA: ordinary text 4.5:1, large text and essential control boundaries 3:1; inactive controls remain recognizable. Pair semantic colors with text/icons. Provide persistent labels, visible keyboard focus, logical reading order, meaningful icon-button labels, 44–48px touch targets, FR/EN copy, and 200% text support. Test long names, large amounts, phone/tablet/desktop widths, landscape and keyboard-open forms. Do not hide essential information to fix an overflow.

## Local token pipeline and themes

`packages/edaya_shared/design-system/tokens.json` is an identical, versioned snapshot of the canonical frontend manifest. `python3 scripts/brand-tokens.py` generates `edaya_tokens.g.dart`; `--check` verifies drift without network or another checkout. Import a reviewed version explicitly with `--sync-from /path/to/tokens.json`. Commit the snapshot and generated Dart together. `AppTheme`, `EdayaColors` and `EdayaTypography` remain the theme entry points.

Retain existing light/dark/system preferences. Dark mode uses navy `#0F172A` canvas, `#1E293B` surfaces, `#F1F5F9` text, `#CBD5E1` secondary text, sky `#60A5FA` primary with navy foreground, stronger `#94A3B8` controls, and `#475569` separators. Success `#86EFAC`, warning `#FBBF24`, danger `#FCA5A5` and information `#93C5FD` sit on their dark semantic surfaces. Do not reuse a light contrast pair blindly in dark mode.

Fonts and license files are registered in the shared package. Poppins is a heading family, never a replacement for the wordmark. `EdayaBrandLogo` uses PNG derivatives of the supplied SVG outlines with reserved clear space. `ResponsiveMetrics` wraps existing values according to available width and text scaling; never changes their calculation.

## Current application patterns

| Application | Keep | Refine |
|---|---|---|
| Guardian | Login, waiting when no child is linked, Calendar, Academic, Evaluations, Fees, Inbox; student/year switches; existing details | Student identity wrapping; year selector on its own header row; lesson/event hierarchy; readable fees and score summaries; inbox title/body scanning |
| Teacher | Calendar, Evaluations, Teaching, Report Cards; filters; attendance gestures; marks/logbook/report editors | Class/session context; neutral student names with semantic attendance labels; readable roster actions and fields; distinct locked/disabled state; sheet hierarchy |

Keep bottom navigation on both phone and tablet, with all existing destination labels/icons. Operational headers prioritize active student, class, session and year. Context headers accommodate enlargement; do not introduce a dashboard, Home tab, navigation rail, master/detail route or alternative detail flow from an old proposal. Constrain tablet operational content to 1120 logical pixels and modal sheets to 840 while retaining the same routes and dismissal behavior. Forms stay scrollable above the keyboard.

Shared Material primitives provide 48px filled/outlined actions, visible input boundaries, 16px cards, 24px sheets/dialogs, semantic segmented selection and labeled navigation. Reuse `DataState`, `PersonAvatar`, `AccountSheetBody`, `ModalBottomSheetPage` and the existing feature widgets. Use Inter for numeric summaries and amounts. Keep all attendance states and gestures; use text/icon in addition to color, and do not color a student's entire identity row as an error. Locked marks keep their original disabled condition and explanatory text.

Login is email OTP only: email → send code → verification code, with resend and a different-email action on the code step. Keep developer settings. After sign-in, guardians with linked children open Calendar; guardians with a verified account but no linked child open the waiting screen (vertical logo, friendly copy, check-again and sign-out). Use the vertical supplied logo and clear heading hierarchy, with a scrollable form. Do not add password, magic-link, or recovery methods.

## Launcher and launch assets

Guardian: color symbol on white. Teacher: white symbol on royal blue. Keep names, bundle/application IDs, versioning, signing, and launch transitions unchanged. Existing native launch screens use the same background as their launcher. Android adaptive foreground artwork stays inside its safe central mask region; background is a separate layer. iOS icons are opaque. Use committed generated resolutions and retain source SVGs separately from runtime PNG assets. Mobile favicons use the same app symbol at required platform sizes.

## Reuse and exception review

Before any new component, inspect the shared package and the current feature widgets. Prefer extending a primitive or presentation wrapper over replacing effective UI. Controllers own data and business decisions; local presentation must consume existing signals. Reuse requires full loading/empty/error/content, enabled/disabled, selected, busy and focus states. Keep FR/EN strings in the localization system.

Document visual exceptions with component, rationale, alternatives considered, owner, scope/lifetime and contrast/responsive evidence. Review the concrete exception before adding it to the token manifest or literal allowlist. A visual change updates tokens, generated files, this spec, component registry and current gallery metadata together. Keep implementation trackers under `docs/sprints`, historical feature proposals under `docs/proposals`, and human-facing references separate from this normative specification.

Run `melos run verify` and relevant existing integration journeys with isolated test data. The deterministic design-review tests render current production pages/components without network; their evidence does not establish live API or authentication success. Capture FR/EN, phone/tablet, light/dark and enlarged text, and verify keyboard-open forms and touch targets. Gallery metadata records source revision/digest, design version, locale, theme and viewport. Remove superseded gallery packs after replacing them. Git preserves historical versions.
