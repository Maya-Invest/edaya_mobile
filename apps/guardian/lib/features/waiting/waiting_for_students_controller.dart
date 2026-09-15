import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

class WaitingForStudentsController extends LevitController
    with LevitReactiveTasksMixin {
  WaitingForStudentsController({
    required AppSessionController session,
    required Future<void> Function() onCheckAgain,
  }) : _session = session,
       _onCheckAgain = onCheckAgain;

  final AppSessionController _session;
  final Future<void> Function() _onCheckAgain;

  Future<void> checkAgain() {
    return runTask(_onCheckAgain, id: 'check-again');
  }

  Future<void> signOut() => _session.signOut();
}
