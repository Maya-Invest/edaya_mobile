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
    String? Function()? resolveActorKind,
    bool Function()? allowUnlinkedIdentity,
    Future<void> Function()? onSignOut,
  }) : _authClient = authClient,
       _sessionStorage = sessionStorage,
       _pushNotifications = pushNotifications,
       _routerRefresh = routerRefresh,
       _validateGrants = validateGrants,
       _unauthorizedProfileMessage = unauthorizedProfileMessage,
       _resolveAcademicYearId = resolveAcademicYearId,
       _resolveActorKind = resolveActorKind,
       _allowUnlinkedIdentity = allowUnlinkedIdentity,
       _onSignOut = onSignOut;

  final AuthClient _authClient;
  final AuthSessionStorage _sessionStorage;
  final PushNotificationService _pushNotifications;
  final EdayaRouterRefresh _routerRefresh;
  final GrantValidator _validateGrants;
  final String Function() _unauthorizedProfileMessage;
  final Future<String?> Function()? _resolveAcademicYearId;
  final String? Function()? _resolveActorKind;
  final bool Function()? _allowUnlinkedIdentity;
  final Future<void> Function()? _onSignOut;

  String? _academicYearIdHeader;
  String? _actorKindHeader;

  final user = LxVar<AuthUser?>(null);
  final grants = LxVar<api.EffectiveGrantsResponse?>(null);
  String? get actorIdHeader => grants.value?.actorId;
  String? get schoolIdHeader => grants.value?.schoolId;
  final isBootstrapping = LxVar(true);
  final isSigningOut = LxVar(false);

  bool get isAuthenticated => user.value != null;

  bool get allowUnlinkedIdentity => _allowUnlinkedIdentity?.call() ?? false;

  bool get hasSchoolSession => grants.value != null;

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
        if (allowUnlinkedIdentity) {
          await _completeIdentityOnly(result.data!.user);
        } else {
          await _clearLocalSession(persistCookies: false);
        }
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
      if (allowUnlinkedIdentity) {
        await _completeIdentityOnly(signedInUser);
        return null;
      }
      return error;
    }

    await _sessionStorage.markLoggedIn();
    await _sessionStorage.persist(_authClient);
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
      try {
        await _authClient.signOut();
      } finally {
        await _sessionStorage.markLoggedOut();
        await _clearLocalSession();
        await _onSignOut?.call();
        _routerRefresh.refresh();
      }
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

    final error = await _loadSchoolSession(user.value!);
    if (error == null && grants.value != null) {
      await _pushNotifications.registerForAuthenticatedUser();
    }
    return error;
  }

  Future<void> _completeIdentityOnly(AuthUser signedInUser) async {
    user(signedInUser);
    grants(null);
    await _sessionStorage.markLoggedIn();
    await _sessionStorage.persist(_authClient);
    _routerRefresh.refresh();
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
    _actorKindHeader = _resolveActorKind?.call();
    return createEdayaSchoolClient(
      _authClient,
      getAcademicYearId: () => _academicYearIdHeader,
      getActorKind: () => _actorKindHeader,
      getActorId: () => grants.value?.actorId,
      getSchoolId: () => grants.value?.schoolId,
    );
  }

  Future<void> _clearLocalSession({bool persistCookies = true}) async {
    user(null);
    grants(null);
    _academicYearIdHeader = null;
    _actorKindHeader = null;
    if (persistCookies) {
      await _sessionStorage.clearCookies();
      _authClient.clearCredentials();
    }
  }
}
