import 'dart:async';
import 'dart:convert';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_runtime.dart' if (dart.library.io) 'push_runtime_io.dart';

// --- Configuration -----------------------------------------------------------

/// Per-app notification channel and display settings.
class PushNotificationConfig {
  const PushNotificationConfig({required this.androidChannelId, required this.androidChannelName, this.androidChannelDescription = ''});

  final String androidChannelId;
  final String androidChannelName;
  final String androidChannelDescription;
}

/// Default push notification channel settings per app.
abstract final class PushNotificationConfigs {
  static const guardian = PushNotificationConfig(
    androidChannelId: 'edaya_guardian_default',
    androidChannelName: 'Edaya Guardian',
    androidChannelDescription: 'School updates and alerts for guardians',
  );

  static const teacher = PushNotificationConfig(
    androidChannelId: 'edaya_teacher_default',
    androidChannelName: 'Edaya Staff',
    androidChannelDescription: 'School updates and alerts for staff',
  );
}

// --- Service interface -------------------------------------------------------

/// Push notification adapter used during auth bootstrap.
abstract class PushNotificationService {
  Future<void> initialize();

  Future<void> registerForAuthenticatedUser();

  Future<void> unregister();

  /// Opens any notification that launched the app once auth bootstrap finishes.
  Future<void> consumePendingNavigation() async {}
}

// --- Deep links --------------------------------------------------------------

/// Parsed navigation target from an FCM [RemoteMessage].
class NotificationDeepLink {
  const NotificationDeepLink({required this.path, this.data = const {}});

  final String path;
  final Map<String, String> data;

  String? get deliveryId => data['deliveryId'];
}

/// Normalizes FCM data, including JSON payloads from foreground local taps.
Map<String, String> notificationMessageData(RemoteMessage message) {
  final data = <String, String>{};

  for (final entry in message.data.entries) {
    if (entry.key == 'payload' && entry.value.isNotEmpty) {
      try {
        final decoded = jsonDecode(entry.value);
        if (decoded is Map) {
          for (final nested in decoded.entries) {
            data[nested.key.toString()] = nested.value?.toString() ?? '';
          }
        }
      } on Object {
        data[entry.key] = entry.value;
      }
      continue;
    }
    data[entry.key] = entry.value;
  }

  return data;
}

/// Resolves a go_router path from common FCM data keys.
NotificationDeepLink? parseNotificationDeepLink(RemoteMessage message) {
  final data = notificationMessageData(message);

  final explicitRoute = data['route'] ?? data['path'];
  if (explicitRoute != null && explicitRoute.isNotEmpty) {
    return NotificationDeepLink(path: explicitRoute, data: data);
  }

  final deliveryId = data['deliveryId'];
  if (deliveryId != null && deliveryId.isNotEmpty) {
    return NotificationDeepLink(path: '/inbox/message', data: data);
  }

  return switch (data['screen'] ?? data['type']) {
    'inbox' => NotificationDeepLink(path: '/inbox', data: data),
    'calendar' => NotificationDeepLink(path: '/calendar', data: data),
    'evaluations' => NotificationDeepLink(path: '/evaluations', data: data),
    'fees' => NotificationDeepLink(path: '/fees', data: data),
    'academic' => NotificationDeepLink(path: '/academic', data: data),
    _ => null,
  };
}

// --- Background handler ------------------------------------------------------

/// Registers the FCM background handler.
///
/// Call from `main()` before [Firebase.initializeApp] and `runApp`.
void registerEdayaFcmBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(edayaFcmBackgroundHandler);
}

/// Handles FCM messages while the app is terminated or in the background.
@pragma('vm:entry-point')
Future<void> edayaFcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// --- FCM implementation ------------------------------------------------------

/// FCM push notifications with foreground display via local notifications.
class FcmPushNotificationService implements PushNotificationService {
  FcmPushNotificationService({
    required api.SchoolClient Function() schoolClientFactory,
    required PushNotificationConfig config,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotificationsPlugin,
    this.onNotificationOpened,
  }) : _schoolClientFactory = schoolClientFactory,
       _config = config,
       _messagingOverride = messaging,
       _localNotificationsPlugin = localNotificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final api.SchoolClient Function() _schoolClientFactory;
  final PushNotificationConfig _config;
  final FirebaseMessaging? _messagingOverride;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin;

  final void Function(RemoteMessage message)? onNotificationOpened;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  String? _registeredToken;
  RemoteMessage? _pendingOpenedMessage;
  var _localNotificationsInitialized = false;
  var _notificationIdCounter = 0;
  var _initialized = false;

  FirebaseMessaging get _messaging => _messagingOverride ?? FirebaseMessaging.instance;

  bool get _isDisabled => kIsWeb || isFlutterTest;

  @override
  Future<void> initialize() async {
    if (_isDisabled || _initialized) {
      return;
    }

    _initialized = true;

    try {
      await _initializeLocalNotifications();

      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
        unawaited(_registerToken(token));
      });

      _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen((message) {
        unawaited(_showForegroundNotification(message));
      });

      _openedAppSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _pendingOpenedMessage = initialMessage;
      }
    } on Object {
      // Firebase may be unavailable in widget tests or before APNS is ready.
    }
  }

  @override
  Future<void> registerForAuthenticatedUser() async {
    if (_isDisabled) {
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await _registerToken(token);
    } on Object {
      // APNS token not available yet (common on iOS Simulator).
    }
  }

  @override
  Future<void> consumePendingNavigation() async {
    final message = _pendingOpenedMessage;
    _pendingOpenedMessage = null;
    if (message != null) {
      _handleNotificationOpened(message);
    }
  }

  @override
  Future<void> unregister() async {
    if (_isDisabled) {
      return;
    }

    try {
      final token = _registeredToken ?? await _messaging.getToken();
      if (token != null) {
        try {
          await _schoolClientFactory().unregisterPushDevice({'provider': 'fcm'});
        } on Object {
          // Best-effort — local session is cleared regardless.
        }
      }

      _registeredToken = null;
      await _messaging.deleteToken();
    } on Object {
      _registeredToken = null;
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _openedAppSubscription = null;
    _initialized = false;
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || onNotificationOpened == null) {
          return;
        }
        onNotificationOpened!(RemoteMessage(data: {'payload': payload}));
      },
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _config.androidChannelId,
          _config.androidChannelName,
          description: _config.androidChannelDescription,
          importance: Importance.high,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();
    }

    _localNotificationsInitialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    final payload = message.data.isEmpty ? null : jsonEncode(message.data);
    final androidDetails = message.notification?.android;

    await _localNotificationsPlugin.show(
      _notificationIdCounter++,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _config.androidChannelId,
          _config.androidChannelName,
          channelDescription: _config.androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: androidDetails?.smallIcon ?? '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: payload,
    );
  }

  void _handleNotificationOpened(RemoteMessage message) {
    onNotificationOpened?.call(message);
  }

  Future<void> _registerToken(String token) async {
    if (_registeredToken == token) {
      return;
    }

    try {
      await _schoolClientFactory().registerPushDevice({'token': token, 'provider': 'fcm'});
      _registeredToken = token;
    } on Object {
      // Token registration is optional until push is fully configured.
    }
  }
}
