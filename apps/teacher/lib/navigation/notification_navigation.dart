import 'package:edaya_shared/edaya_shared.dart';

import '../access/app_runtime.dart';
import '../app/router.dart';
import 'teacher_notification_targets.dart';

/// Routes the user after they open a push notification in the teacher app.
void handleTeacherNotificationOpened(RemoteMessage message) {
  if (!AppRuntime.session.isAuthenticated) {
    return;
  }

  final link = parseNotificationDeepLink(message);
  if (link == null) {
    return;
  }

  final path = resolveTeacherNotificationPath(link);
  if (path == null) {
    return;
  }

  AppRouter.find.router.go(path);
}
