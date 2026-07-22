import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../app/router.dart';
import '../features/context/student_context_controller.dart';
import '../mock/mock_store.dart';

/// Notifies [GoRouter] when auth (or other redirect-relevant) state changes.
class PrototypeRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

void registerPrototypeDependencies(LevitScope scope, {MockStore? store}) {
  final mockStore = store ?? MockStore();

  scope.put<MockStore>(() => mockStore, permanent: true);
  scope.put<PrototypeRouterRefresh>(
    () {
      final refresh = PrototypeRouterRefresh();
      // Mirror former refreshListenable: store so auth redirects keep working.
      mockStore.addListener(refresh.refresh);
      return refresh;
    },
    permanent: true,
  );
  scope.put<StudentContextController>(
    () => StudentContextController(store: scope.find<MockStore>()),
    permanent: true,
  );
  scope.put<GoRouter>(
    () => createRouter(
      scope.find<MockStore>(),
      routerRefresh: scope.find<PrototypeRouterRefresh>(),
    ),
    permanent: true,
  );
}
