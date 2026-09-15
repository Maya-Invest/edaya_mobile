# Current EDAYA Teacher review

Design system **1.0.0**. [Open gallery](index.html) · [Capture provenance](manifest.json) · [Mobile specification](../../../docs/specs/design-language-spec.md) · [Component registry](../../../docs/specs/shared-components-spec.md).

These captures render current production pages/components with deterministic, fictional fixtures. They establish presentation and layout, not live API or authentication success. Each manifest entry records app, source revision plus working-tree source digest, design version, locale, viewport, theme, text scale and capture time. Only the current app is represented.

| Example | Review annotations |
|---|---|
| Calendar | Current Calendar page and four-destination navigation; class/session context remains prominent; restrained blue emphasis and tablet content bounds. |
| Attendance/marks components | Explicit composition of production `AttendanceRowTile` and `MarkRowTile`, not a replacement attendance or marks screen. Student identity stays neutral, status remains labeled, and published marks retain disabled editing. |
| Login | Current shared login fields and callbacks, supplied vertical artwork, local Inter/Poppins, clear heading hierarchy. |
| Dark mode | Existing light/dark/system preferences remain; navy surfaces, readable sky actions, separate semantic colors. |
| Large text | 200% text, long names and large values. Scrollable content and wrapped metrics retain information. Standard navigation labels wrap. |
| Keyboard inset | Login with a simulated 320px keyboard inset; email/code field focus and submit visibility are checked. The OS keyboard itself is not rendered by widget tests. |

## Refreshing evidence

From this app directory, run `EDAYA_CAPTURE_DESIGN_REVIEW=1 flutter test test/design_review_test.dart`. The test loads bundled fonts and Material icons, renders current widgets and rejects layout exceptions. Run `python3 scripts/brand-gallery.py` from the repository root afterward to regenerate metadata and the HTML index. Then run `melos run verify` and applicable live journeys against isolated fixtures.

Current galleries replace retired screenshot packs. Keep before/after comparisons in temporary QA artifacts; do not retain superseded visual directives here. A design change updates tokens, specs, registry and gallery metadata together.
