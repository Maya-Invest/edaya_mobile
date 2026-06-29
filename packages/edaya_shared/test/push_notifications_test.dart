import 'package:edaya_shared/edaya_shared.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveNotificationDisplayContent prefers notification payload', () {
    final content = resolveNotificationDisplayContent(
      const RemoteMessage(
        notification: RemoteNotification(title: 'Hello', body: 'World'),
      ),
    );

    expect(content?.title, 'Hello');
    expect(content?.body, 'World');
  });

  test('resolveNotificationDisplayContent falls back to data payload', () {
    final content = resolveNotificationDisplayContent(
      const RemoteMessage(
        data: {
          'title': 'Announcement',
          'body': 'School is closed tomorrow',
        },
      ),
    );

    expect(content?.title, 'Announcement');
    expect(content?.body, 'School is closed tomorrow');
  });

  test('resolveNotificationDisplayContent decodes nested payload json', () {
    final content = resolveNotificationDisplayContent(
      RemoteMessage(
        data: {
          'payload': '{"title":"Nested","body":"From Novu"}',
        },
      ),
    );

    expect(content?.title, 'Nested');
    expect(content?.body, 'From Novu');
  });
}
