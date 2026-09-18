import 'package:edaya_api_client/edaya_api_client.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_lookup.dart';

/// Keeps existing feature errors, with common reload guidance for conflicts.
String mutationFailureMessage(
  Object error,
  String fallback, {
  AppLocalizations? l10n,
}) {
  if (error is ApiError && error.status == 409) {
    return (l10n ?? systemL10n()).mutationConflict;
  }
  return fallback;
}

/// Runs only display reconciliation after a confirmed write, never the write.
/// A failed refresh must not turn a saved result into a retryable failure.
Future<void> refreshAfterMutation(
  Future<void> Function() refresh, {
  required void Function(String) showWarning,
  AppLocalizations? l10n,
}) async {
  try {
    await refresh();
  } on Object {
    showWarning((l10n ?? systemL10n()).mutationSavedRefreshFailed);
  }
}
