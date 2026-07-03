import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../features/auth/app_bootstrap_controller.dart';
import '../features/settings/app_settings_controller.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import 'edaya_root_scope.dart';
import 'theme.dart';

/// Provides the [RouterConfig] for [MaterialApp.router].
abstract class EdayaAppRouter {
  RouterConfig<Object> config();
}

class EdayaAppRoot extends StatelessWidget {
  const EdayaAppRoot({super.key, required this.scopeName, required this.appTitle, required this.registerDependencies});

  final String scopeName;
  final String appTitle;
  final void Function(LevitScope scope) registerDependencies;

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: scopeName,
      dependencyFactory: registerDependencies,
      child: EdayaBootstrapGate(appTitle: appTitle),
    );
  }
}

class EdayaBootstrapGate extends LView<AppBootstrapController> {
  const EdayaBootstrapGate({super.key, required this.appTitle});

  final String appTitle;

  static const _localizationDelegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  @override
  Widget buildView(BuildContext context, AppBootstrapController controller) {
    final settings = EdayaRootScope.find<AppSettingsController>();

    return LWatch(() {
      settings.theme.value;
      settings.language.value;
      settings.timezone.value;
      settings.dateFormat.value;
      settings.timeFormat.value;

      final themeMode = settings.themeMode;
      final locale = settings.locale;

      if (!controller.isReady.value) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          locale: locale,
          localeResolutionCallback: settings.resolveLocale,
          localizationsDelegates: _localizationDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }

      return MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        locale: locale,
        localeResolutionCallback: settings.resolveLocale,
        localizationsDelegates: _localizationDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: EdayaRootScope.find<EdayaAppRouter>().config(),
      );
    });
  }
}
