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
  });

  final MockStore store;

  /// When true, ensure the store is signed in after DI registration.
  final bool authenticated;

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: 'teacher-prototype',
      dependencyFactory: (scope) {
        registerPrototypeDependencies(scope, store: store);
        if (authenticated && !store.isAuthenticated) {
          store.signIn();
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
      title: 'Edaya Teacher Prototype',
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
