import 'dart:async';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app_session_controller.dart';
import 'session_storage.dart';

/// Restores persisted auth cookies and validates the session on startup.
class AppBootstrapController extends LevitController {
  AppBootstrapController({
    required CookieJar cookieJar,
    required SessionStorage sessionStorage,
    required AppSessionController session,
  }) : _cookieJar = cookieJar,
       _sessionStorage = sessionStorage,
       _session = session;

  final CookieJar _cookieJar;
  final SessionStorage _sessionStorage;
  final AppSessionController _session;

  final isReady = LxVar(false);

  @override
  void onInit() {
    super.onInit();
    autoDispose(isReady);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _sessionStorage.restoreInto(_cookieJar);
    await _session.restoreSession();
    isReady(true);
  }
}
