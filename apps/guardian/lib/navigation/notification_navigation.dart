import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_api_client/edaya_api_client.dart';

import '../access/app_runtime.dart';
import '../common/utils/entity_filters.dart';
import '../app/router.dart';
import '../features/inbox/models/inbox_delivery.dart';

/// Routes the user after they open a push notification in the guardian app.
Future<void> handleGuardianNotificationOpened(RemoteMessage message) async {
  if (!AppRuntime.session.isAuthenticated) {
    return;
  }

  final link = parseNotificationDeepLink(message);
  if (link == null) {
    return;
  }

  final router = AppRouter.find.router;

  if (link.path == '/inbox/message') {
    final deliveryId = link.deliveryId;
    if (deliveryId == null || deliveryId.isEmpty) {
      router.go('/inbox');
      return;
    }

    router.go('/inbox');
    final subjectId = AppRuntime.session.user.value?.id;
    final profile = AppRuntime.session.grants.value;
    if (subjectId == null || profile == null || profile.kind != 'guardian') {
      return;
    }
    try {
      final rows = await AppRuntime.schoolClientInstance().messageDeliveries
          .list({
            ...deliveriesForGuardian(
              subjectId: subjectId,
              guardianId: profile.actorId,
              schoolId: profile.schoolId,
            ),
            'id': deliveryId,
            r'$limit': 1,
          });
      if (rows.isEmpty ||
          AppRuntime.session.user.value?.id != subjectId ||
          AppRuntime.session.grants.value?.kind != profile.kind ||
          AppRuntime.session.grants.value?.actorId != profile.actorId ||
          AppRuntime.session.grants.value?.schoolId != profile.schoolId) {
        return;
      }
      await router.push(
        '/inbox/message',
        extra: InboxDelivery.fromJson(rows.first),
      );
    } on Object {
      // The inbox remains available when a notification is no longer accessible.
      return;
    }
    return;
  }

  router.go(link.path);
}
