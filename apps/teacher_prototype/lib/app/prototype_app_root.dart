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
      name: 'teacher-prototype',
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

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp.router(
      title: 'Edaya Teacher',
      theme: PrototypeTheme.light,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: context.levit.find<GoRouter>(),
      debugShowCheckedModeBanner: false,
    );

    if (!live) {
      return app;
    }

    return LWatch(() {
      final ready = context.levit.find<AppBootstrapController>().isReady.value;
      return MaterialApp.router(
        title: 'Edaya Teacher',
        theme: PrototypeTheme.light,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
