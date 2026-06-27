import 'package:levit_flutter/levit_flutter.dart';

abstract final class TeacherRootScope {
  static LevitScope? _scope;

  static void bind(LevitScope scope) {
    _scope = scope;
  }

  static T find<T>() {
    final scope = _scope;
    if (scope == null) {
      throw StateError('TeacherRootScope is not initialized.');
    }
    return scope.find<T>();
  }
}
