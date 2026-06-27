import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'platform_env.dart' if (dart.library.io) 'platform_env_io.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Registers the device FCM token with Novu via the school API.
///
/// Push setup is best-effort: failures (e.g. iOS Simulator without APNS) must
/// not block auth or app startup.
class PushNotificationService {
  PushNotificationService({
    required api.SchoolClient Function() schoolClientFactory,
    FirebaseMessaging? messaging,
  }) : _schoolClientFactory = schoolClientFactory,
       _messagingOverride = messaging;

  final api.SchoolClient Function() _schoolClientFactory;
  final FirebaseMessaging? _messagingOverride;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _registeredToken;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  Future<void> initialize() async {
    if (kIsWeb || isFlutterTest) {
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
        unawaited(_registerToken(token));
      });
    } on Object {
      // Firebase may be unavailable in widget tests or before APNS is ready.
    }
  }

  Future<void> registerForAuthenticatedUser() async {
    if (kIsWeb || isFlutterTest) {
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await _registerToken(token);
    } on Object {
      // APNS token not available yet (common on iOS Simulator / without push capability).
    }
  }

  Future<void> unregister() async {
    if (kIsWeb || isFlutterTest) {
      return;
    }

    try {
      final token = _registeredToken ?? await _messaging.getToken();
      if (token != null) {
        try {
          await _schoolClientFactory().unregisterPushDevice({
            'provider': 'fcm',
          });
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
    _tokenRefreshSubscription = null;
  }

  Future<void> _registerToken(String token) async {
    if (_registeredToken == token) {
      return;
    }

    try {
      await _schoolClientFactory().registerPushDevice({
        'token': token,
        'provider': 'fcm',
      });
      _registeredToken = token;
    } on Object {
      // Token registration is optional until push is fully configured.
    }
  }
}
