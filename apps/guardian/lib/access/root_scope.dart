import 'package:levit_flutter/levit_flutter.dart';

/// Root [LevitScope] for app-wide dependency lookup outside widget trees.
abstract final class GuardianRootScope {
  static LevitScope? _scope;

  static void bind(LevitScope scope) {
    _scope = scope;
  }

  static T find<T>() {
    final scope = _scope;
    if (scope == null) {
      throw StateError('GuardianRootScope is not initialized.');
    }
    return scope.find<T>();
  }
}
