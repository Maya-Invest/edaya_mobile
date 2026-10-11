# Brand inputs

The frontend `design-system/tokens.json` is canonical. Mobile keeps a reviewed local snapshot; verification and builds never read sibling repositories. Generate tokens with `dart run edaya_repo:repo generate brand`, then check with `dart run edaya_repo:repo check`.

`assets.json` records SHA-256 integrity for bundled artwork, fonts and licenses. `visual-literals.json` records existing per-file literals as migration debt. Checks reject increases, missing/changed assets, runtime font fetching, generated drift and inaccessible semantic text pairs. Record an explicitly reviewed inventory with `dart run edaya_repo:repo generate reviewed-brand-baseline` and inspect the resulting diff.

Artwork derives from the supplied EDAYA outlined SVGs. Mobile uses `dart run edaya_repo:repo generate assets`, implemented with Flutter rendering, for PNG and native launch/icon outputs. Generated brand assets remain committed.
