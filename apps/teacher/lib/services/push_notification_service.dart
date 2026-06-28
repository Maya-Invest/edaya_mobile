import 'package:edaya_shared/edaya_shared.dart';

/// No-op push adapter for the teacher app (notifications planned for a later phase).
class TeacherPushNotificationService implements PushNotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> registerForAuthenticatedUser() async {}

  @override
  Future<void> unregister() async {}
}
