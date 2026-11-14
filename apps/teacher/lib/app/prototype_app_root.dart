import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../design/theme.dart';
import '../di/prototype_module.dart';
import '../mock/mock_store.dart';

/// Root widget: app-lifetime [LScope] + MaterialApp.router.
class PrototypeAppRoot extends StatelessWidget {
  const PrototypeAppRoot({
    super.key,
    required this.store,
    this.authenticated = false,
    this.live = false,
  });

  final MockStore store;

  /// When true, ensure the store is signed in after DI registration.
  final bool authenticated;

  /// Production Accueil uses Identity OTP + school API. Tests keep [live] false.
  final bool live;

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: 'teacher',
      dependencyFactory: (scope) {
        registerPrototypeDependencies(scope, store: store, live: live);
        if (authenticated && !store.isAuthenticated) {
          store.signIn();
        }
      },
      child: _PrototypeMaterialApp(live: live),
    );
  }
}

class _PrototypeMaterialApp extends StatelessWidget {
  const _PrototypeMaterialApp({required this.live});

  final bool live;

  static const _localizationDelegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.levit.find<AppSettingsController>();
    return LWatch(() {
      settings.theme.value;
      settings.language.value;
      settings.timezone.value;
      settings.dateFormat.value;
      settings.timeFormat.value;
      final ready = live
          ? context.levit.find<AppBootstrapController>().isReady.value
          : true;
      return MaterialApp.router(
        title: systemL10n().appTitleTeacher,
        theme: PrototypeTheme.light,
        darkTheme: PrototypeTheme.dark,
        themeMode: settings.themeMode,
        locale: settings.locale,
        localeResolutionCallback: settings.resolveLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: _localizationDelegates,
        routerConfig: context.levit.find<GoRouter>(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          if (!ready) {
            return const EdayaStartupScreen();
          }
          return child ?? const SizedBox.shrink();
        },
      );
    });
  }
}
