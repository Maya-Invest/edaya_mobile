import 'package:levit_flutter/levit_flutter.dart';

/// Root [LevitScope] for app-wide dependency lookup outside widget trees.
abstract final class EdayaRootScope {
  static LevitScope? _scope;
  static String _appName = 'EDaya';

  static void bind(LevitScope scope, {required String appName}) {
    _scope = scope;
    _appName = appName;
  }

  static T find<T>() {
    final scope = _scope;
    if (scope == null) {
      throw StateError('$_appName root scope is not initialized.');
    }
    return scope.find<T>();
  }
}
