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
  const PrototypeAppRoot({super.key, this.store, this.authenticated = false});

  /// When non-null, registers mock harness DI (widget / design-review tests).
  final MockStore? store;

  /// When true with [store], ensure the store is signed in after DI registration.
  final bool authenticated;

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: store == null ? 'guardian-prototype' : 'guardian-prototype-test',
      dependencyFactory: (scope) {
        registerPrototypeDependencies(scope, store: store);
        if (store != null && authenticated && !store!.isAuthenticated) {
          store!.signIn();
        }
      },
      child: store == null
          ? const _ApiBootstrapApp()
          : const _PrototypeMaterialApp(),
    );
  }
}

class _ApiBootstrapApp extends LView<AppBootstrapController> {
  const _ApiBootstrapApp();

  @override
  Widget buildView(BuildContext context, AppBootstrapController controller) {
    return LWatch(() {
      controller.isReady.value;
      return MaterialApp.router(
        title: 'Edaya Guardian',
        theme: PrototypeTheme.light,
        darkTheme: PrototypeTheme.dark,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: context.levit.find<GoRouter>(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          if (!controller.isReady.value) {
            return const EdayaStartupScreen();
          }
          return child ?? const SizedBox.shrink();
        },
      );
    });
  }
}

class _PrototypeMaterialApp extends StatelessWidget {
  const _PrototypeMaterialApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Edaya Guardian Prototype',
      theme: PrototypeTheme.light,
      darkTheme: PrototypeTheme.dark,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: context.levit.find<GoRouter>(),
      debugShowCheckedModeBanner: false,
    );
  }
}
