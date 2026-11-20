# Repository integration

See [independent CI and releases](ci-setup.md) for destination-branch acquisition, compatibility gates, artifact handoff and rollout requirements.


## Backend input

Production resolves backend `main`; staging resolves backend `staging`. Resolve once and detach at that SHA. A moving branch cannot change an existing checkout or generated client. The selected branch identifies the source tested, not necessarily the currently deployed backend.

Local preparation defaults to staging. `--ref <branch-or-commit>` is an explicit local override. `--backend-root <clean-checkout>` accepts an already resolved checkout. Ordinary CI selects only the destination branch; overrides are exposed by Manual validation. Integrations verify the backend checkout still equals the prepared client's commit and has no tracked edits before starting services.

`BACKEND_CHECKOUT_TOKEN` needs read-only contents access to `Maya-Invest/edaya_backend`. It is used only for source checkout. Package-registry credentials and write permissions are no longer needed. Cache identities include backend SHA, generator/runtime inputs and relevant lockfiles; invalid checksum entries are rebuilt. Generated inputs are transferred with qualification artifacts and checked again before release.
