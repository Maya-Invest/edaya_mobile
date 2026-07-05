import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/school_client.dart';
import '../../app/router_refresh.dart';
import '../../l10n/l10n_lookup.dart';
import '../push/push_notifications.dart';
import 'auth_session_storage.dart';

typedef GrantValidator = String? Function(api.EffectiveGrantsResponse grants);

/// Root session state shared across auth screens.
class AppSessionController extends LevitController {
  AppSessionController({
    required AuthClient authClient,
    required AuthSessionStorage sessionStorage,
    required PushNotificationService pushNotifications,
    required EdayaRouterRefresh routerRefresh,
    required GrantValidator validateGrants,
    required String Function() unauthorizedProfileMessage,
    Future<String?> Function()? resolveAcademicYearId,
  }) : _authClient = authClient,
       _sessionStorage = sessionStorage,
       _pushNotifications = pushNotifications,
       _routerRefresh = routerRefresh,
       _validateGrants = validateGrants,
       _unauthorizedProfileMessage = unauthorizedProfileMessage,
       _resolveAcademicYearId = resolveAcademicYearId;

  final AuthClient _authClient;
  final AuthSessionStorage _sessionStorage;
  final PushNotificationService _pushNotifications;
  final EdayaRouterRefresh _routerRefresh;
  final GrantValidator _validateGrants;
  final String Function() _unauthorizedProfileMessage;
  final Future<String?> Function()? _resolveAcademicYearId;

  String? _academicYearIdHeader;

  final user = LxVar<AuthUser?>(null);
  final grants = LxVar<api.EffectiveGrantsResponse?>(null);
  final isBootstrapping = LxVar(true);
  final isSigningOut = LxVar(false);

  bool get isAuthenticated => user.value != null;

  @override
  void onInit() {
    super.onInit();
    autoDispose(user);
    autoDispose(grants);
    autoDispose(isBootstrapping);
    autoDispose(isSigningOut);
  }

  Future<void> restoreSession() async {
    isBootstrapping(true);

    try {
      if (await _sessionStorage.isLoggedOut()) {
        return;
      }

      final result = await _authClient.getSession();
      if (!result.isSuccess || result.data == null) {
        return;
      }

      final error = await _loadSchoolSession(result.data!.user);
      if (error != null) {
        await _clearLocalSession(persistCookies: false);
      } else {
        await _pushNotifications.registerForAuthenticatedUser();
      }
    } finally {
      isBootstrapping(false);
    }
  }

  Future<String?> completeSignIn(AuthUser signedInUser) async {
    final error = await _loadSchoolSession(signedInUser);
    if (error != null) {
      return error;
    }

    await _sessionStorage.markLoggedIn();
    await _sessionStorage.persist(_authClient.cookieJar);
    await _pushNotifications.registerForAuthenticatedUser();
    _routerRefresh.refresh();
    return null;
  }

  Future<void> signOut() async {
    if (isSigningOut.value) {
      return;
    }

    isSigningOut(true);
    try {
      await _pushNotifications.unregister();
      await _authClient.signOut();
      await _sessionStorage.markLoggedOut();
      await _clearLocalSession();
      _routerRefresh.refresh();
    } finally {
      isSigningOut(false);
    }
  }

  /// Clears local auth state after switching API endpoints.
  ///
  /// This intentionally does not call the remote sign-out endpoint because the
  /// app may already be pointing at a different server.
  Future<void> clearForApiUrlChange() async {
    await _sessionStorage.markLoggedOut();
    await _clearLocalSession();
    _routerRefresh.refresh();
  }

  /// Re-fetches effective grants (e.g. after academic year selection for staff).
  Future<String?> refreshGrants() async {
    if (user.value == null) {
      return null;
    }

    return _loadSchoolSession(user.value!);
  }

  Future<String?> _loadSchoolSession(AuthUser signedInUser) async {
    final schoolClient = await _createSchoolClient();
    try {
      final effectiveGrants = await schoolClient.effectiveGrants();
      final validationError = _validateGrants(effectiveGrants);
      if (validationError != null) {
        return validationError;
      }
      user(signedInUser);
      grants(effectiveGrants);
      _routerRefresh.refresh();
      return null;
    } on api.ApiError catch (error) {
      if (error.status == 401) {
        return _unauthorizedProfileMessage();
      }
      return systemL10n().signedInSchoolSessionUnavailable('$error');
    } on Object catch (error) {
      return systemL10n().signedInSchoolSessionUnavailable('$error');
    }
  }

  Future<api.SchoolClient> _createSchoolClient() async {
    if (_resolveAcademicYearId != null) {
      _academicYearIdHeader = await _resolveAcademicYearId();
    }
    return createEdayaSchoolClient(
      _authClient,
      getAcademicYearId: () => _academicYearIdHeader,
    );
  }

  Future<void> _clearLocalSession({bool persistCookies = true}) async {
    user(null);
    grants(null);
    _academicYearIdHeader = null;
    if (persistCookies) {
      await _sessionStorage.clearCookies();
      _authClient.cookieJar.clear();
    }
  }
}
