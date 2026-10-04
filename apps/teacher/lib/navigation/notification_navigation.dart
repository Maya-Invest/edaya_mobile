import 'package:edaya_shared/edaya_shared.dart';
import 'package:go_router/go_router.dart';

import 'teacher_notification_targets.dart';

final _conversationNavigation = ConversationNotificationNavigation();

/// Routes the user after they open a push notification in the teacher app.
void handleTeacherNotificationOpened(RemoteMessage message) {
  final session = EdayaRootScope.find<AppSessionController>();
  if (_conversationNavigation.handle(
    message,
    session: session,
    kind: 'teacher',
    onReady: (path) => EdayaRootScope.find<GoRouter>().go(path),
  )) {
    return;
  }
  if (!session.isAuthenticated) {
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

  EdayaRootScope.find<GoRouter>().go(path);
}
