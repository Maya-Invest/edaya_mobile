@Tags(['integration'])
library;

import 'package:edaya_guardian_v2/app/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../tooling/flutter_integration/route_inventory.dart';

void main() {
  test(
    '[guardian-v2.coverage.routes] inventories the registered production GoRouter tree',
    () {
      final refresh = ChangeNotifier();
      final router = createRouter(routerRefresh: refresh);
      addTearDown(router.dispose);
      addTearDown(refresh.dispose);
      final paths = registeredRoutePaths(router);
      expect(paths, isNotEmpty);
      expect(
        paths.toSet().length,
        paths.length,
        reason: 'Duplicate registered route',
      );
      reportRouteInventory(router);
    },
  );
}
