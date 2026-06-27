import 'dart:async';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../services/push_notification_service.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'app_session_controller.dart';
import 'session_storage.dart';

/// Restores persisted auth cookies and validates the session on startup.
class AppBootstrapController extends LevitController {
  AppBootstrapController({
    required CookieJar cookieJar,
    required SessionStorage sessionStorage,
    required AppSessionController session,
    required PushNotificationService pushNotifications,
    required AcademicYearController academicYear,
    required StudentContextController studentContext,
  }) : _cookieJar = cookieJar,
       _sessionStorage = sessionStorage,
       _session = session,
       _pushNotifications = pushNotifications,
       _academicYear = academicYear,
       _studentContext = studentContext;

  final CookieJar _cookieJar;
  final SessionStorage _sessionStorage;
  final AppSessionController _session;
  final PushNotificationService _pushNotifications;
  final AcademicYearController _academicYear;
  final StudentContextController _studentContext;

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
      await _sessionStorage.restoreInto(_cookieJar);
      await _session.restoreSession();
      if (_session.isAuthenticated) {
        await _academicYear.loadYears();
        await _studentContext.initializeFromSession();
      }
    } finally {
      isReady(true);
    }
  }
}
