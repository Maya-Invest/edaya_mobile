import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:edaya_guardian_v2/design/theme.dart';
import 'package:edaya_guardian_v2/di/prototype_module.dart';
import 'package:edaya_guardian_v2/mock/mock_store.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'design_review_capture.dart';
import 'design_review_config.dart';

class PrototypeWidgetTestHarness {
  PrototypeWidgetTestHarness();

  late MockStore store;
  Size? viewportSize;
  Locale locale = const Locale('fr', 'FR');
  double? textScale;
  ThemeMode? mode;

  LevitScope? _scope;

  /// Levit scope after [buildApp] has been pumped.
  LevitScope get scope {
    final resolved = _scope;
    if (resolved == null) {
      throw StateError(
        'Prototype harness: pump buildApp() before accessing scope/router',
      );
    }
    return resolved;
  }

  GoRouter get router => scope.find<GoRouter>();

  void bootstrap({required bool authenticated}) {
    store = MockStore();
    if (authenticated) {
      store.signIn();
    } else {
      store.signOut();
    }
  }

  Widget designReviewRoot({required Widget child}) {
    final framed = viewportSize == null
        ? child
        : SizedBox(
            width: viewportSize!.width,
            height: viewportSize!.height,
            child: child,
          );
    return RepaintBoundary(key: designReviewRootKey, child: framed);
  }

  Widget buildApp() {
    _scope = null;
    return LScope(
      name: 'guardian-prototype-test-${identityHashCode(this)}',
      dependencyFactory: (scope) {
        _scope = scope;
        registerPrototypeDependencies(scope, store: store);
      },
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  textScale ?? designReviewTextScale(),
                ),
              ),
              child: child!,
            ),
            title: 'Edaya Guardian Prototype',
            theme: PrototypeTheme.light,
            darkTheme: PrototypeTheme.dark,
            themeMode:
                mode ??
                (designReviewTheme() == 'dark'
                    ? ThemeMode.dark
                    : ThemeMode.light),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: context.levit.find<GoRouter>(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
