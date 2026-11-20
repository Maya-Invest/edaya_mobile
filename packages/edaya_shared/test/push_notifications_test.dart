import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('iOS push registration', () {
    late _Messaging messaging;
    late _SchoolClient school;
    late FcmPushNotificationService service;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      messaging = _Messaging();
      school = _SchoolClient();
      service = FcmPushNotificationService(
        schoolClientFactory: () => school,
        config: PushNotificationConfigs.guardian,
        messaging: messaging,
        localNotificationsPlugin: _LocalNotifications(),
      );
    });
    tearDown(() async {
      await service.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    test('waits for APNs and retries a failed school registration', () async {
      school.failures = 1;
      await service.registerForAuthenticatedUser();
      expect(messaging.tokenRequests, 0);
      expect(messaging.isAutoInitEnabled, false);
      expect(school.tokens, isEmpty);

      messaging.apnsToken = 'apns';
      await school.registered.future.timeout(const Duration(seconds: 5));
      expect(school.tokens, ['fcm', 'fcm']);
    });

    test('sign-out cancels registration while APNs is pending', () async {
      await service.registerForAuthenticatedUser();
      await service.unregister();
      messaging.apnsToken = 'apns';
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(messaging.tokenRequests, 0);
      expect(messaging.isAutoInitEnabled, false);
      expect(school.tokens, isEmpty);
    });
  });

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
        data: {'title': 'Announcement', 'body': 'School is closed tomorrow'},
      ),
    );

    expect(content?.title, 'Announcement');
    expect(content?.body, 'School is closed tomorrow');
  });

  test('resolveNotificationDisplayContent decodes nested payload json', () {
    final content = resolveNotificationDisplayContent(
      const RemoteMessage(
        data: {'payload': '{"title":"Nested","body":"From Novu"}'},
      ),
    );

    expect(content?.title, 'Nested');
    expect(content?.body, 'From Novu');
  });
}

class _SchoolClient extends Fake implements SchoolClient {
  final registered = Completer<void>();
  final tokens = <String>[];
  int failures = 0;

  @override
  Future<Map<String, dynamic>> runCommand(
    String publicName,
    Map<String, dynamic> payload,
  ) async {
    expect(publicName, 'register-push-device');
    tokens.add(payload['token'] as String);
    if (failures > 0) {
      failures--;
      throw StateError('Registration temporarily unavailable');
    }
    registered.complete();
    return {};
  }
}

class _Messaging extends Fake implements FirebaseMessaging {
  String? apnsToken;
  int tokenRequests = 0;

  @override
  bool isAutoInitEnabled = false;

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {
    isAutoInitEnabled = enabled;
  }

  @override
  Future<String?> getAPNSToken() async => apnsToken;

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    tokenRequests++;
    expect(apnsToken, isNotNull);
    return 'fcm';
  }

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async => const NotificationSettings(
    alert: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.disabled,
    authorizationStatus: AuthorizationStatus.authorized,
    badge: AppleNotificationSetting.enabled,
    carPlay: AppleNotificationSetting.disabled,
    criticalAlert: AppleNotificationSetting.disabled,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    providesAppNotificationSettings: AppleNotificationSetting.disabled,
    showPreviews: AppleShowPreviewSetting.always,
    sound: AppleNotificationSetting.enabled,
    timeSensitive: AppleNotificationSetting.disabled,
  );

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {}
}

class _LocalNotifications extends Fake
    implements FlutterLocalNotificationsPlugin {
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;
}
