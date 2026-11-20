import 'package:levit_flutter/levit_flutter.dart';

/// Draft writes replace the register at a specific revision. Read that revision
/// inside each queued operation, after the previous save has settled.
class AttendanceDraftQueue {
  final writing = LxVar(false);
  Future<void> _tail = Future.value();
  Future<void> get settled => _tail;

  Future<bool> add(
    Future<bool> Function() write, {
    required bool Function() active,
  }) {
    writing(true);
    final result = _tail.then<bool>((_) => active() ? write() : false);
    // A failed operation is reported to its caller; later pupils can still save.
    final tail = _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result.whenComplete(() {
      if (active() && identical(tail, _tail)) writing(false);
    });
  }
}
