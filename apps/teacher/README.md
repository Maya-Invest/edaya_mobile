# EDAYA Teacher

Current Flutter app: Calendar, Evaluations, Teaching, Report Cards; class filters, attendance and marks. Authentication, routing and domain controllers are preserved through UI work.

Run from this directory with `flutter run` and the existing `AUTH_URL` / `API_URL` defines. Build and signing instructions remain in the root README and `android-signing/README.md`.

UI contract: [mobile design language](../../docs/specs/design-language-spec.md). Shared foundation: `packages/edaya_shared`, EDAYA tokens 1.0.0, local Poppins/Inter and supplied artwork. Human brief: `edaya_frontend/docs/reference/edaya-ui-brief.md` in the frontend repository (not a build dependency).

[Current visual review](design-review/README.md) renders production pages/components with isolated fixtures. Generate from this directory using `EDAYA_CAPTURE_DESIGN_REVIEW=1 flutter test test/design_review_test.dart`. These captures do not test live API authentication. Run `melos run verify` at repository root; relevant live journeys use `melos run test:integration` with isolated seeded services.
