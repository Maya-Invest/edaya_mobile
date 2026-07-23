import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../app/router.dart';
import '../mock/mock_store.dart';

/// Registers mock harness dependencies for the teacher prototype.
void registerPrototypeDependencies(LevitScope scope, {required MockStore store}) {
  scope.put<MockStore>(() => store, permanent: true);
  scope.put<EdayaRouterRefresh>(() => EdayaRouterRefresh(), permanent: true);
  scope.put<MockTeacherContextBridge>(
    () => MockTeacherContextBridge(store: store),
    permanent: true,
  );
  scope.put<GoRouter>(
    () => createRouter(
      routerRefresh: scope.find<EdayaRouterRefresh>(),
      mockStore: store,
    ),
    permanent: true,
  );
  store.addListener(() => scope.find<EdayaRouterRefresh>().refresh());
}

/// Listenable used by [GoRouter] to re-run redirects when auth/context changes.
class EdayaRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Adapts [MockStore] for shell chrome rebuilds.
class MockTeacherContextBridge extends LevitController {
  MockTeacherContextBridge({required MockStore store}) : _store = store;

  final MockStore _store;
  final storeTick = LxVar(0);

  MockStore get store => _store;

  @override
  void onInit() {
    super.onInit();
    autoDispose(storeTick);
    _store.addListener(() => storeTick.value++);
  }
}
