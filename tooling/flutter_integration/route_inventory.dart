import 'dart:convert';
import 'package:go_router/go_router.dart';

/// Traverse the actual registered router, including nested and shell routes.
List<String> registeredRoutePaths(GoRouter router) {
  final paths = <String>[];
  void visit(List<RouteBase> routes, String parent) {
    for (final route in routes) {
      if (route is GoRoute) {
        final path = route.path.startsWith('/') ? route.path : '$parent/${route.path}';
        paths.add(path);
        visit(route.routes, path);
      } else if (route is ShellRouteBase) {
        visit(route.routes, parent);
      }
    }
  }
  visit(router.configuration.routes, '');
  return paths..sort();
}

void reportRouteInventory(GoRouter router) {
  print('EDAYA_ROUTE_INVENTORY:${jsonEncode(registeredRoutePaths(router))}');
}
