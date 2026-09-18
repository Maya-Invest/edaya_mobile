import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:teacher_prototype/design/theme.dart';
import 'package:teacher_prototype/di/prototype_module.dart';
import 'package:teacher_prototype/mock/mock_store.dart';

import 'design_review_capture.dart';

class PrototypeWidgetTestHarness {
  PrototypeWidgetTestHarness();

  late MockStore store;
  Size? viewportSize;

  LevitScope? _scope;

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
      name: 'teacher-prototype-test-${identityHashCode(this)}',
      dependencyFactory: (scope) {
        _scope = scope;
        registerPrototypeDependencies(scope, store: store);
      },
      child: Builder(
        builder: (context) {
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
        },
      ),
    );
  }
}
