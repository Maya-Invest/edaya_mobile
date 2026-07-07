import 'package:flutter/widgets.dart';

import '../features/settings/app_settings_models.dart';
import '../features/settings/app_settings_storage.dart';
import 'app_localizations.dart';

/// Resolves localized strings outside widget trees (e.g. controllers).
AppLocalizations systemL10n() {
  final preferred = AppSettingsStorage.cached.language.locale;
  final locale = preferred ?? WidgetsBinding.instance.platformDispatcher.locale;
  return lookupAppLocalizations(locale);
}
