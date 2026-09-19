import 'package:edaya_shared/edaya_shared.dart';

class NoOpPushNotificationService implements PushNotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> registerForAuthenticatedUser() async {}

  @override
  Future<void> unregister() async {}

  @override
  Future<void> consumePendingNavigation() async {}
}
