/// Push notification adapter used during auth bootstrap.
abstract class PushNotificationService {
  Future<void> initialize();

  Future<void> registerForAuthenticatedUser();

  Future<void> unregister();
}
