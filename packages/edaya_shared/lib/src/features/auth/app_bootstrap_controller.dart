import 'dart:async';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../push/push_notifications.dart';
import 'app_session_controller.dart';
import 'auth_session_storage.dart';

/// Restores persisted auth cookies and validates the session on startup.
class AppBootstrapController extends LevitController {
  AppBootstrapController({
    required AuthClient authClient,
    required AuthSessionStorage sessionStorage,
    required AppSessionController session,
    required PushNotificationService pushNotifications,
    required Future<void> Function() initializeAuthenticatedContext,
    Future<void> Function()? hydratePendingInvitation,
  }) : _authClient = authClient,
       _sessionStorage = sessionStorage,
       _session = session,
       _pushNotifications = pushNotifications,
       _initializeAuthenticatedContext = initializeAuthenticatedContext,
       _hydratePendingInvitation = hydratePendingInvitation;

  final AuthClient _authClient;
  final AuthSessionStorage _sessionStorage;
  final AppSessionController _session;
  final PushNotificationService _pushNotifications;
  final Future<void> Function() _initializeAuthenticatedContext;
  final Future<void> Function()? _hydratePendingInvitation;

  final isReady = LxVar(false);

  @override
  void onInit() {
    super.onInit();
    autoDispose(isReady);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _pushNotifications.initialize();
      await _hydratePendingInvitation?.call();
      await _sessionStorage.restoreInto(_authClient);
      await _session.restoreSession();
      if (_session.isAuthenticated) {
        await _initializeAuthenticatedContext();
        await _pushNotifications.consumePendingNavigation();
      }
    } finally {
      isReady(true);
    }
  }
}
