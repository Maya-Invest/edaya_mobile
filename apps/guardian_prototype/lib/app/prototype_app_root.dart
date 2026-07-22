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
    this.store,
    this.authenticated = false,
  });

  /// Optional pre-built store (tests / design-review harness).
  final MockStore? store;

  /// When true, ensure the store is signed in after DI registration.
  final bool authenticated;

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: 'guardian-prototype',
      dependencyFactory: (scope) {
        registerPrototypeDependencies(scope, store: store);
        if (authenticated) {
          final mock = scope.find<MockStore>();
          if (!mock.isAuthenticated) {
            mock.signIn();
          }
        }
      },
      child: const _PrototypeMaterialApp(),
    );
  }
}

class _PrototypeMaterialApp extends StatelessWidget {
  const _PrototypeMaterialApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Edaya Guardian Prototype',
      theme: PrototypeTheme.light,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: context.levit.find<GoRouter>(),
      debugShowCheckedModeBanner: false,
    );
  }
}
