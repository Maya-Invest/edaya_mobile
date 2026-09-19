import 'package:edaya_shared/edaya_shared.dart';

import '../access/app_runtime.dart';
import '../app/router.dart';
import '../features/inbox/models/inbox_delivery.dart';

/// Routes the user after they open a push notification in the guardian app.
void handleGuardianNotificationOpened(RemoteMessage message) {
  if (!AppRuntime.session.isAuthenticated) {
    return;
  }

  final link = parseNotificationDeepLink(message);
  if (link == null) {
    return;
  }

  final router = AppRouter.find.router;
  final data = notificationMessageData(message);
  final notification = message.notification;

  if (link.path == '/inbox/message') {
    final deliveryId = link.deliveryId;
    if (deliveryId == null || deliveryId.isEmpty) {
      router.go('/inbox');
      return;
    }

    final delivery = InboxDelivery(
      id: deliveryId,
      subjectId: data['subjectId'] ?? '',
      status: InboxDeliveryStatus.fromApi(data['status']),
      title:
          data['title'] ??
          notification?.title ??
          systemL10n().messageDefaultTitle,
      body: data['body'] ?? notification?.body ?? '',
      announcementId: data['announcementId'],
      eventKey: data['eventKey'],
    );
    router.go('/inbox');
    Future.microtask(() => router.push('/inbox/message', extra: delivery));
    return;
  }

  router.go(link.path);
}
