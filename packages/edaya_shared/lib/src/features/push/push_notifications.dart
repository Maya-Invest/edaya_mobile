import 'package:flutter/services.dart' show PlatformException;
import 'dart:async';
import '../../l10n/l10n_lookup.dart';
import '../../l10n/app_localizations.dart';
import '../settings/app_settings_storage.dart';
import '../../demo/demo_host.dart';
import '../messaging/messaging_events.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/evaluation_data.dart';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_runtime.dart' if (dart.library.io) 'push_runtime_io.dart';

// Android small notification icons use a monochrome drawable, not an adaptive
// launcher icon, whose background becomes an opaque silhouette.
const _androidNotificationIcon = '@drawable/ic_stat_notification';

// --- Background isolate configuration ----------------------------------------

FirebaseOptions? _fcmBackgroundFirebaseOptions;
PushNotificationConfig? _fcmBackgroundConfig;
final FlutterLocalNotificationsPlugin _backgroundLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
var _backgroundLocalNotificationsReady = false;
var _backgroundNotificationId = 0;

/// Supplies Firebase and channel settings for the FCM background isolate.
///
/// Call from `main()` before [registerEdayaFcmBackgroundHandler].
void configureEdayaFcm({
  required FirebaseOptions firebaseOptions,
  required PushNotificationConfig notificationConfig,
}) {
  _fcmBackgroundFirebaseOptions = firebaseOptions;
  _fcmBackgroundConfig = notificationConfig;
}

// --- Configuration -----------------------------------------------------------

/// Per-app notification channel and display settings.
class PushNotificationConfig {
  const PushNotificationConfig({
    required this.androidChannelId,
    this.appId = 'guardian',
    required this.androidChannelName,
    String androidChannelDescription = '',
    this.descriptionBuilder,
  }) : _description = androidChannelDescription;

  final String appId;
  final String androidChannelId;
  final String androidChannelName;
  final String _description;
  final String Function(AppLocalizations)? descriptionBuilder;
  String get androidChannelDescription =>
      descriptionBuilder?.call(systemL10n()) ?? _description;
}

/// Default push notification channel settings per app.
abstract final class PushNotificationConfigs {
  static String _guardian(AppLocalizations tr) => tr.guardianPushDescription;
  static String _teacher(AppLocalizations tr) => tr.teacherPushDescription;

  static const guardian = PushNotificationConfig(
    androidChannelId: 'edaya_guardian_default',
    androidChannelName: 'EDaya Guardian',
    descriptionBuilder: _guardian,
  );

  static const teacher = PushNotificationConfig(
    appId: 'teacher',
    androidChannelId: 'edaya_teacher_default',
    androidChannelName: 'EDaya Prof',
    descriptionBuilder: _teacher,
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
    final type when type != null && type.startsWith('student_photo') =>
      NotificationDeepLink(path: '/child-profile', data: data),
    final type
        when type != null &&
            (type == 'family_feedback.opened' ||
                type == 'family_feedback.reminder') =>
      NotificationDeepLink(path: '/academic/family-feedback', data: data),
    'family_feedback.published' => NotificationDeepLink(
      path: '/teaching/family-feedback',
      data: data,
    ),
    _ => null,
  };
}

class NotificationDisplayContent {
  const NotificationDisplayContent({required this.title, required this.body});

  final String title;
  final String body;
}

/// Resolves a title/body from FCM notification or data payloads (Novu, etc.).
NotificationDisplayContent? resolveNotificationDisplayContent(
  RemoteMessage message,
) {
  final pushNotification = message.notification;
  final data = notificationMessageData(message);

  final title = pushNotification?.title?.trim().isNotEmpty == true
      ? pushNotification!.title!.trim()
      : _firstNonEmpty(data, const [
          'title',
          'subject',
          'emailSubject',
          'gcm.notification.title',
        ]);
  final body = pushNotification?.body?.trim().isNotEmpty == true
      ? pushNotification!.body!.trim()
      : _firstNonEmpty(data, const [
          'body',
          'message',
          'emailBody',
          'content',
          'gcm.notification.body',
        ]);

  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return null;
  }

  return NotificationDisplayContent(
    title: title?.isNotEmpty == true ? title! : 'EDaya',
    body: body?.isNotEmpty == true ? body! : '',
  );
}

String? _firstNonEmpty(Map<String, String> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

Future<void> _ensureAndroidNotificationChannel(
  FlutterLocalNotificationsPlugin plugin,
  PushNotificationConfig config,
) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(
      config.androidChannelId,
      config.androidChannelName,
      description: config.androidChannelDescription,
      importance: Importance.high,
    ),
  );
}

Future<void> displayEdayaPushNotification(
  RemoteMessage message,
  PushNotificationConfig config, {
  FlutterLocalNotificationsPlugin? plugin,
  int? notificationId,
  String androidIcon = _androidNotificationIcon,
}) async {
  final content = resolveNotificationDisplayContent(message);
  if (content == null) {
    return;
  }

  final notificationsPlugin = plugin ?? _backgroundLocalNotificationsPlugin;
  final payload = message.data.isEmpty ? null : jsonEncode(message.data);

  await notificationsPlugin.show(
    id: notificationId ?? _backgroundNotificationId++,
    title: content.title,
    body: content.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        config.androidChannelId,
        config.androidChannelName,
        channelDescription: config.androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: androidIcon,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: payload,
  );
}

Future<void> _ensureBackgroundLocalNotifications(
  PushNotificationConfig config,
) async {
  if (_backgroundLocalNotificationsReady) {
    return;
  }

  const androidSettings = AndroidInitializationSettings(
    _androidNotificationIcon,
  );
  const iosSettings = DarwinInitializationSettings();

  await _backgroundLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    ),
  );
  await _ensureAndroidNotificationChannel(
    _backgroundLocalNotificationsPlugin,
    config,
  );
  _backgroundLocalNotificationsReady = true;
}

// --- Background handler ------------------------------------------------------

/// Registers the FCM background handler.
///
/// Call from `main()` before [Firebase.initializeApp] and `runApp`.
void registerEdayaFcmBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(edayaFcmBackgroundHandler);
}

/// Handles FCM messages while the app is terminated or in the background.
///
/// Android starts this in a fresh isolate, so callers must pass compile-time
/// Firebase options and channel settings instead of main-isolate globals.
@pragma('vm:entry-point')
Future<void> handleEdayaFcmBackgroundMessage(
  RemoteMessage message, {
  required FirebaseOptions firebaseOptions,
  required PushNotificationConfig notificationConfig,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (await demoActiveInBackground()) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: firebaseOptions);
  }
  await AppSettingsStorage.load();
  await _ensureBackgroundLocalNotifications(notificationConfig);
  await displayEdayaPushNotification(message, notificationConfig);
}

/// Handles FCM messages while the app is terminated or in the background.
@pragma('vm:entry-point')
Future<void> edayaFcmBackgroundHandler(RemoteMessage message) async {
  final options = _fcmBackgroundFirebaseOptions;
  final config = _fcmBackgroundConfig;
  if (options == null || config == null) {
    return;
  }
  await handleEdayaFcmBackgroundMessage(
    message,
    firebaseOptions: options,
    notificationConfig: config,
  );
}

// --- FCM implementation ------------------------------------------------------

/// FCM push notifications with foreground display via local notifications.
class FcmPushNotificationService
    with WidgetsBindingObserver
    implements PushNotificationService {
  FcmPushNotificationService({
    required api.SchoolClient Function() schoolClientFactory,
    required PushNotificationConfig config,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotificationsPlugin,
    this.onNotificationOpened,
  }) : _schoolClientFactory = schoolClientFactory,
       _config = config,
       _messagingOverride = messaging,
       _localNotificationsPlugin =
           localNotificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final api.SchoolClient Function() _schoolClientFactory;
  final PushNotificationConfig _config;
  final FirebaseMessaging? _messagingOverride;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin;

  final void Function(RemoteMessage message)? onNotificationOpened;

  StreamSubscription<void>? _languageSubscription;

  @override
  void didChangeLocales(List<Locale>? locales) => unawaited(_refreshChannel());

  Future<void> _refreshChannel() async {
    if (!_localNotificationsInitialized) return;
    try {
      await _ensureAndroidNotificationChannel(
        _localNotificationsPlugin,
        _config,
      );
    } on PlatformException catch (error) {
      debugPrint('Unable to update notification channel: ${error.code}');
    }
  }

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  Future<void> _registration = Future<void>.value();
  Timer? _registrationRetry;
  var _registrationGeneration = 0;
  var _retryCount = 0;
  var _authenticatedForPush = false;
  var _registrationPending = false;
  var _permissionDenied = false;
  String? _registeredToken;
  RemoteMessage? _pendingOpenedMessage;
  var _localNotificationsInitialized = false;
  var _notificationIdCounter = 0;
  var _initialized = false;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  bool get _isDisabled =>
      kIsWeb || (isFlutterTest && _messagingOverride == null);

  bool get _usesApns => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_usesApns ||
        !_authenticatedForPush ||
        !_registrationPending) {
      return;
    }
    _registrationRetry?.cancel();
    _retryCount = 0;
    unawaited(_queueRegistration(_registrationGeneration));
  }

  @override
  Future<void> initialize() async {
    if (_isDisabled || _initialized) {
      return;
    }

    try {
      await _initializeLocalNotifications();
      if (defaultTargetPlatform == TargetPlatform.android) {
        _languageSubscription ??= AppSettingsStorage.languageChanges.listen(
          (_) => unawaited(_refreshChannel()),
        );
      }

      final settings = await _messaging.requestPermission();
      _permissionDenied =
          settings.authorizationStatus == AuthorizationStatus.denied;
      if (_permissionDenied) {
        return;
      }

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
        if (_authenticatedForPush) {
          unawaited(_queueRegistration(_registrationGeneration, token: token));
        }
      }, onError: (Object error) => _logRegistrationError(error));

      _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen((
        message,
      ) {
        messagingRefreshEvents.add(null);
        unawaited(_showForegroundNotification(message));
      });

      _openedAppSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationOpened,
      );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _pendingOpenedMessage = initialMessage;
      }
      _initialized = true;
    } on Object catch (error) {
      _logRegistrationError(error);
    }
  }

  @override
  Future<void> registerForAuthenticatedUser() async {
    if (_isDisabled) {
      return;
    }

    if (!_authenticatedForPush) {
      WidgetsBinding.instance.addObserver(this);
    }
    _authenticatedForPush = true;
    _registrationPending = true;
    _registrationRetry?.cancel();
    _retryCount = 0;
    await _queueRegistration(++_registrationGeneration);
  }

  Future<void> _queueRegistration(int generation, {String? token}) {
    // Serialize writes so refreshes, profile changes and sign-out cannot
    // leave a late registration behind.
    _registration = _registration.then((_) async {
      if (!_isCurrentRegistration(generation) ||
          (!_registrationPending &&
              (token == null || token == _registeredToken))) {
        return;
      }
      _registrationPending = true;
      try {
        await initialize();
        if (!_isCurrentRegistration(generation) || _permissionDenied) return;
        if (!_initialized ||
            (_usesApns && await _messaging.getAPNSToken() == null)) {
          _retryRegistration(generation);
          return;
        }
        if (!_isCurrentRegistration(generation)) return;
        if (!_messaging.isAutoInitEnabled) {
          await _messaging.setAutoInitEnabled(true);
        }
        final currentToken = token ?? await _messaging.getToken();
        if (currentToken == null || currentToken.isEmpty) {
          _retryRegistration(generation);
          return;
        }
        final installationId = await _installationId();
        if (!_isCurrentRegistration(generation)) return;
        await _schoolClientFactory().registerPushDevice({
          'token': currentToken,
          'provider': 'fcm',
          'appId': _config.appId,
          'installationId': installationId,
        });
        if (!_isCurrentRegistration(generation)) return;
        _registeredToken = currentToken;
        _registrationPending = false;
        _registrationRetry?.cancel();
        _retryCount = 0;
      } on Object catch (error) {
        _logRegistrationError(error);
        _retryRegistration(generation);
      }
    });
    return _registration;
  }

  bool _isCurrentRegistration(int generation) =>
      _authenticatedForPush && generation == _registrationGeneration;

  void _retryRegistration(int generation) {
    // A physical device can receive its APNs token after the permission
    // request completes. Retry without making sign-in wait for APNs.
    if (!_usesApns ||
        !_isCurrentRegistration(generation) ||
        _registrationRetry?.isActive == true ||
        _retryCount >= 6) {
      return;
    }
    final delay = Duration(milliseconds: 250 << _retryCount++);
    _registrationRetry = Timer(delay, () {
      unawaited(_queueRegistration(generation));
    });
  }

  void _logRegistrationError(Object error) {
    if (kDebugMode) {
      debugPrint('Push registration failed: ${error.runtimeType}');
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

    await dispose();
    _registeredToken = null;
    _pendingOpenedMessage = null;
    try {
      await _messaging.setAutoInitEnabled(false);
    } on Object catch (error) {
      _logRegistrationError(error);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final installationId = prefs.getString(_installationKey);
      if (installationId != null) {
        await _schoolClientFactory().unregisterPushDevice({
          'provider': 'fcm',
          'appId': _config.appId,
          'installationId': installationId,
        });
      }
    } on Object catch (error) {
      _logRegistrationError(error);
    }
    try {
      if (!_usesApns || await _messaging.getAPNSToken() != null) {
        await _messaging.deleteToken();
      }
    } on Object catch (error) {
      _logRegistrationError(error);
    }
  }

  Future<void> dispose() async {
    _authenticatedForPush = false;
    _registrationPending = false;
    _registrationGeneration++;
    _registrationRetry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _registration;
    await _languageSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _openedAppSubscription = null;
    _languageSubscription = null;
    _initialized = false;
    _permissionDenied = false;
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      _androidNotificationIcon,
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotificationsPlugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || onNotificationOpened == null) {
          return;
        }
        onNotificationOpened!(RemoteMessage(data: {'payload': payload}));
      },
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await _ensureAndroidNotificationChannel(
        _localNotificationsPlugin,
        _config,
      );
      await androidPlugin?.requestNotificationsPermission();
    }

    _localNotificationsInitialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsInitialized) {
      debugPrint(
        'Foreground push skipped: local notifications not initialized',
      );
      return;
    }

    try {
      final content = resolveNotificationDisplayContent(message);
      if (content == null) {
        debugPrint(
          'Foreground push skipped: no displayable title/body in message',
        );
        return;
      }

      await _localNotificationsPlugin.show(
        id: _notificationIdCounter++,
        title: content.title,
        body: content.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _config.androidChannelId,
            _config.androidChannelName,
            channelDescription: _config.androidChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: _androidNotificationIcon,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.isEmpty ? null : jsonEncode(message.data),
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Foreground push display failed: $error\n$stackTrace');
    }
  }

  void _handleNotificationOpened(RemoteMessage message) {
    onNotificationOpened?.call(message);
  }

  String get _installationKey => 'push.installation.${_config.appId}';

  Future<String> _installationId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installationKey);
    if (existing != null) return existing;
    final id = newSchoolRequestId();
    await prefs.setString(_installationKey, id);
    return id;
  }
}
