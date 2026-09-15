import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseNotificationDeepLink resolves student photo review', () {
    final link = parseNotificationDeepLink(
      const RemoteMessage(data: {'type': 'student_photo.approved'}),
    );

    expect(link?.path, '/child-profile');
  });

  test('parseNotificationDeepLink resolves inbox delivery id', () {
    final link = parseNotificationDeepLink(
      const RemoteMessage(data: {'deliveryId': 'delivery-1', 'title': 'Hello'}),
    );

    expect(link?.path, '/inbox/message');
    expect(link?.deliveryId, 'delivery-1');
  });

  test('notificationMessageData decodes foreground local payload', () {
    final data = notificationMessageData(
      const RemoteMessage(
        data: {'payload': '{"deliveryId":"delivery-2","route":"/inbox"}'},
      ),
    );

    expect(data['deliveryId'], 'delivery-2');
    expect(data['route'], '/inbox');
  });
}
