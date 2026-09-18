import 'package:flutter/material.dart';

/// Primary shell destinations (hubs) and overlay classification.
abstract final class GuardianShellTabs {
  static const hubPaths = [
    '/home',
    '/calendar',
    '/scolarite/notes',
    '/fees',
    '/inbox',
  ];

  static bool isHub(String path) {
    return path == '/home' ||
        path == '/calendar' ||
        path == '/scolarite/notes' ||
        path == '/fees' ||
        path == '/inbox' ||
        path == '/inbox/avis';
  }

  /// Tab for a location, or `null` when the route is a global overlay
  /// (`/child`, `/account`, `/settings`) that keeps the last tab selected.
  static int? tabIndexFor(String path) {
    if (path.startsWith('/account') ||
        path.startsWith('/settings') ||
        path.startsWith('/child')) {
      return null;
    }
    if (path.startsWith('/session') ||
        path.startsWith('/attendance') ||
        path.startsWith('/calendar')) {
      return 1;
    }
    if (path.startsWith('/scolarite') ||
        path.startsWith('/grade') ||
        path.startsWith('/report-card')) {
      return 2;
    }
    if (path.startsWith('/fees')) {
      return 3;
    }
    if (path.startsWith('/inbox')) {
      return 4;
    }
    if (path.startsWith('/home')) {
      return 0;
    }
    return null;
  }

  static String hubPathForIndex(int index) {
    if (index < 0 || index >= hubPaths.length) {
      return hubPaths.first;
    }
    return hubPaths[index];
  }
}

/// Provides the current tab hub path to overlay pages (close / scrim).
class GuardianShellScope extends InheritedWidget {
  const GuardianShellScope({
    super.key,
    required this.hubPath,
    required this.tabIndex,
    required super.child,
  });

  final String hubPath;
  final int tabIndex;

  static GuardianShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GuardianShellScope>();
  }

  @override
  bool updateShouldNotify(GuardianShellScope oldWidget) {
    return hubPath != oldWidget.hubPath || tabIndex != oldWidget.tabIndex;
  }
}
