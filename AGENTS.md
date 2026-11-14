# Mobile agent guidance

Release targets are `apps/guardian_v2` and `apps/teacher_v2` on Android and iOS. Preserve the existing Android store IDs and signing aliases. The original `apps/guardian` and `apps/teacher` remain in verification but are not published. Read `docs/specs/design-language-spec.md` and `docs/specs/shared-components-spec.md` before UI work and `spec/levit/AGENTS.md` before Levit changes. Current source defines behavior; historical proposals do not authorize features.

Use generated EDAYA 1.0.0 tokens, bundled Poppins/Inter, supplied logo assets, and existing shared/feature widgets. Preserve controllers, routes, grants, data, validation and action outcomes. UI specifications are normative; human reference material and implementation trackers remain separate. Update specs, component registry and current examples with design changes. Run `melos run verify` and relevant isolated integration journeys. Do not restore old gallery packs or font dependencies.
