import 'package:edaya_shared/edaya_shared.dart';
import 'package:go_router/go_router.dart';

import '../features/inbox/inbox_routes.dart';

/// Routes the user after they open a push notification in the guardian app.
void handleGuardianNotificationOpened(RemoteMessage message) {
  final session = EdayaRootScope.find<AppSessionController>();
  if (!session.isAuthenticated) {
    return;
  }

  final link = parseNotificationDeepLink(message);
  if (link == null) {
    return;
  }

  final router = EdayaRootScope.find<GoRouter>();

  if (link.path == '/inbox/message' || link.path.startsWith('/inbox/message')) {
    final deliveryId = link.deliveryId;
    if (deliveryId == null || deliveryId.isEmpty) {
      router.go('/inbox');
      return;
    }
    router.go(inboxMessagePath(deliveryId));
    return;
  }

  router.go(link.path);
}
