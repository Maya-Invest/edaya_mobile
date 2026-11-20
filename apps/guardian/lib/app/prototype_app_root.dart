import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../design/theme.dart';
import '../di/prototype_module.dart';
import '../mock/mock_store.dart';

/// Root widget: app-lifetime [LScope] + MaterialApp.router (prototype theme).
class PrototypeAppRoot extends StatelessWidget {
  const PrototypeAppRoot({
    super.key,
    this.store,
    this.authenticated = false,
    this.demo,
  });

  /// When non-null, registers mock harness DI (widget / design-review tests).
  final MockStore? store;

  /// When true with [store], ensure the store is signed in after DI registration.
  final bool authenticated;
  final DemoStore? demo;

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: store == null ? 'guardian-prototype' : 'guardian-prototype-test',
      dependencyFactory: (scope) {
        registerPrototypeDependencies(
          scope,
          demo: demo,
          store: store,
          live: store == null,
        );
        if (store != null && authenticated && !store!.isAuthenticated) {
          store!.signIn();
        }
      },
      child: _PrototypeMaterialApp(live: store == null),
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
        title: systemL10n().appTitleGuardian,
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
          return DemoFrame(child: child ?? const SizedBox.shrink());
        },
      );
    });
  }
}
