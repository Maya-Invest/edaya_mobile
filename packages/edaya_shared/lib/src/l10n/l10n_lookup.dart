import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/widgets.dart';

import '../features/settings/app_settings_models.dart';
import '../features/settings/app_settings_storage.dart';
import 'app_localizations.dart';

Locale supportedAppLocale(Locale? requested, Iterable<Locale> supported) =>
    supported.firstWhere(
      (locale) => locale.languageCode == requested?.languageCode,
      orElse: () => supported.first,
    );

/// Resolves localized strings outside widget trees (e.g. controllers).
AppLocalizations systemL10n() {
  final preferred = AppSettingsStorage.cached.language.locale;
  final locale = preferred ?? PlatformDispatcher.instance.locale;
  return lookupAppLocalizations(
    supportedAppLocale(locale, AppLocalizations.supportedLocales),
  );
}
