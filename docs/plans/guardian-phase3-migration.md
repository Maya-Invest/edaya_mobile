# Guardian next-app — Parallel build (complete)

> **Status:** Phase B cutover complete — production app is `apps/guardian` (former prototype). Archived IA: `apps/guardian_legacy`.

> **Strategy (historical):** Evolve `apps/guardian_prototype` into the new production Guardian. Keep old `apps/guardian` **untouched** until verified, then replace.

## Outcome

| Role | Path | Package |
|------|------|---------|
| Production Guardian | `apps/guardian` | `edaya_guardian` |
| Archived pre-cutover IA | `apps/guardian_legacy` | `edaya_guardian_legacy` |

Identity: Android/iOS `ca.mayainvest.edaya.guardian`, Firebase configs + Play signing from the former production app.

## Melos

- `run:guardian:local` / `run:guardian:staging` → new app
- `run:guardian:legacy:local` / `run:guardian:legacy:staging` → archive
- `screenshots:guardian:review` → new app design-review
- `screenshots:guardian:legacy:review` → archived IA (API)
- `test:integration` → live API tests for **new** `apps/guardian` (+ teacher + tooling)

## Remaining follow-ups

- Manual portal grant smoke (guardian actor) against local/staging with seeded demo accounts
- Remove `apps/guardian_legacy` when no longer needed as fallback
