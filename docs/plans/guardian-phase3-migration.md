# Guardian Phase 3 — Production migration checklist

> **Status:** Deferred. Complete after prototype sign-off in `apps/guardian_prototype`.

## Prerequisites

- [ ] Design language spec approved (`docs/specs/design-language-spec.md`)
- [ ] Prototype reviewed on 390px phone (FR labels, all routes)
- [ ] Galak Round commercial license secured (or substitute font chosen)

## 1. Move design system to `edaya_shared`

| Prototype path | Production path |
|----------------|-----------------|
| `lib/design/colors.dart` | `packages/edaya_shared/lib/src/app/edaya_colors.dart` (extend) |
| `lib/design/typography.dart` | `packages/edaya_shared/lib/src/app/edaya_typography.dart` |
| `lib/design/spacing.dart` | `packages/edaya_shared/lib/src/app/edaya_spacing.dart` (new) |
| `lib/design/theme.dart` | `packages/edaya_shared/lib/src/app/theme.dart` |
| `lib/design/components/*` | `packages/edaya_shared/lib/src/ui/*` |

- [ ] Register fonts in `edaya_shared/pubspec.yaml`
- [ ] Remove runtime `google_fonts` dependency from theme path
- [ ] Export new components from `edaya_shared.dart`

## 2. Guardian app IA

| Prototype route | Production route |
|-----------------|------------------|
| `/home` | `/home` (new) |
| `/calendar` | `/calendar` |
| `/scolarite/*` | `/scolarite/*` (merge `/academic` + `/evaluations`) |
| `/fees` | `/fees` |
| `/inbox` | `/inbox` |

- [ ] Update `app_shell_controller.dart` tab indices
- [ ] Add l10n keys: `navHome`, `navAgenda`, `navMessages`
- [ ] Redirect `/academic` and `/evaluations` → `/scolarite`
- [ ] Post-login → `/home`

## 3. Screen mapping

Map each prototype screen to production widget; replace `MockStore` with existing Levit controllers + API client.

## 4. Verification

- [ ] `bun run verify` in `edaya_mobile`
- [ ] Regenerate `melos run screenshots:guardian:review`
- [ ] Teacher app spot-check (shared theme)
- [ ] Portal authorization unchanged

## 5. Out of scope for Phase 3 initial pass

- Live API aggregate endpoint for Home
- Production auth / build flavors
- App Store release with Galak demo font
