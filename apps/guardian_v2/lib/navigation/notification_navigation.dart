import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:go_router/go_router.dart';

import '../features/context/student_context_controller.dart';
import '../features/inbox/inbox_routes.dart';

final _conversationNavigation = ConversationNotificationNavigation();

/// Routes the user after they open a push notification in the guardian app.
void handleGuardianNotificationOpened(RemoteMessage message) {
  final session = EdayaRootScope.find<AppSessionController>();
  if (_conversationNavigation.handle(
    message,
    session: session,
    kind: 'guardian',
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

  final router = EdayaRootScope.find<GoRouter>();
  final studentId = message.data['studentId'];
  if (studentId != null && studentId.isNotEmpty) {
    final students = EdayaRootScope.find<StudentContextController>();
    unawaited(students.selectStudent(studentId));
  }

  final path = link.path == '/child-profile' ? '/child' : link.path;
  const supported = {'/child', '/inbox', '/fees', '/calendar', '/scolarite'};
  if (!supported.contains(path) && !path.startsWith('/inbox')) {
    router.go('/inbox');
    return;
  }

  if (path == '/inbox/message' || path.startsWith('/inbox/message')) {
    final deliveryId = link.deliveryId;
    if (deliveryId == null || deliveryId.isEmpty) {
      router.go('/inbox');
      return;
    }
    router.go(inboxMessagePath(deliveryId));
    return;
  }

  router.go(path);
}
