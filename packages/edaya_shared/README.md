# Shared mobile package

`lib/src` contains the current Guardian/Teacher app shell, authentication and selected-profile access, shared API helpers, controllers, widgets and localization. `lib/edaya_shared.dart` exposes the supported shared API; `test` contains isolated unit and widget checks.

`mutationFailureMessage(error, fallback)` preserves feature error text and supplies FR/EN reload-and-review guidance for HTTP 409. It does not infer permission or retry the request. `refreshAfterMutation(refresh, showWarning: ...)` accepts only display reconciliation after a confirmed server write. If that refresh fails, it reports that the change was saved; callers retain the successful result rather than rolling back or submitting again. The account profile and teacher mark flows use this contract.

Loading, empty, error and ready presentation continues through `DataState`. Its optional retry callback reloads current data. Business requests retain the generated client and selected-profile headers. Token renewal may retry GET/HEAD once; mutations are not automatically replayed.

Edit localization in `lib/l10n/*.arb` and regenerate using `flutter gen-l10n` in this package. Run repository `melos run verify` for generated/brand drift, static analysis, and isolated tests. Actual provider/device qualification is separate.

`PersonAvatar` resolves protected `/core/files/{attachmentId}/content` portraits through the scoped `SchoolClientFactory` download grant, then fetches signed storage images without API credentials. Same-origin local memory-storage routes retain bearer authentication and one renewal retry, with redirects disabled. Local storage URLs follow the configured emulator host. It uses the scoped `AuthClient` HTTP transport and falls back to initials on denied or unavailable images. App wrappers can retain their brand presentation through `backgroundColor` and `initialsStyle`.
