import '../context/store_backed_controller.dart';

class SessionDetailController extends StoreBackedController {
  SessionDetailController(super.store, {required this.sessionId});

  final String sessionId;
}
