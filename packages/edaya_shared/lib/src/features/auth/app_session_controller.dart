import 'dart:async';
import '../../demo/demo_store.dart';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:shared_preferences/shared_preferences.dart';
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
    this.selectFirstProfile = false,
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

  /// Opt-in for apps whose workspace picker owns school selection.
  final bool selectFirstProfile;
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
  String? _pinnedActorId;
  String? _pinnedSchoolId;
  String? _pinnedActorKind;

  final user = LxVar<AuthUser?>(null);
  final grants = LxVar<api.EffectiveGrantsResponse?>(null);
  final availableProfiles = LxVar<List<SchoolAuthorizationProfile>>(const []);
  String? get actorIdHeader => grants.value?.actorId;
  String? get schoolIdHeader => grants.value?.schoolId;
  final isBootstrapping = LxVar(true);
  final isSigningOut = LxVar(false);

  bool get isAuthenticated => user.value != null;

  bool get allowUnlinkedIdentity => _allowUnlinkedIdentity?.call() ?? false;

  DemoStore? get demo =>
      _authClient is DemoAuthClient ? _authClient.store : null;
  String get _prefix => demo?.prefix ?? '';

  bool get hasSchoolSession => grants.value != null;

  bool get needsProfileSelection =>
      grants.value == null &&
      _pinnedActorId == null &&
      availableProfiles.value.length > 1;

  @override
  void onInit() {
    super.onInit();
    autoDispose(user);
    autoDispose(grants);
    autoDispose(availableProfiles);
    autoDispose(isBootstrapping);
    autoDispose(isSigningOut);
  }

  Future<void> restoreSession() async {
    isBootstrapping(true);

    try {
      if (demo case final local?) {
        final error = await _loadSchoolSession(local.user);
        if (error != null) throw StateError(error);
        _routerRefresh.refresh();
        return;
      }
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
    if (demo != null) return null;
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
    if (demo != null || isSigningOut.value) {
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
    if (demo != null) return;
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

  Future<String?> selectProfile(SchoolAuthorizationProfile profile) async {
    final signedInUser = user.value;
    if (signedInUser == null) {
      return _unauthorizedProfileMessage();
    }
    _pinnedActorId = profile.actorId;
    _pinnedSchoolId = profile.schoolId;
    _pinnedActorKind = profile.kind;
    grants(null);
    await _persistPinnedProfile();
    final error = await _loadSchoolSession(signedInUser);
    if (error == null && grants.value != null) {
      await _pushNotifications.registerForAuthenticatedUser();
      _routerRefresh.refresh();
    }
    return error;
  }

  Future<String?> _loadSchoolSession(AuthUser signedInUser) async {
    final schoolClient = await _createSchoolClient();
    try {
      await _resolveProfile(schoolClient);
      if (needsProfileSelection) {
        user(signedInUser);
        grants(null);
        _routerRefresh.refresh();
        return null;
      }
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
    _actorKindHeader = _pinnedActorKind ?? _resolveActorKind?.call();
    return createEdayaSchoolClient(
      _authClient,
      getAcademicYearId: () => _academicYearIdHeader,
      getActorKind: () => _actorKindHeader,
      getActorId: () => _pinnedActorId ?? grants.value?.actorId,
      getSchoolId: () => _pinnedSchoolId ?? grants.value?.schoolId,
    );
  }

  Future<void> _resolveProfile(api.SchoolClient schoolClient) async {
    final rows = await schoolClient.authorizationProfiles();
    final profiles =
        [
          for (final row in rows)
            SchoolAuthorizationProfile(
              kind: row['kind'] as String? ?? '',
              actorId: row['actorId'] as String? ?? '',
              schoolId: row['schoolId'] as String? ?? '',
              schoolName: row['schoolName'] as String? ?? '',
              schoolShortName: row['schoolShortName'] as String? ?? '',
            ),
        ].where(
          (profile) =>
              profile.actorId.isNotEmpty && profile.schoolId.isNotEmpty,
        );
    final expectedKind = _resolveActorKind?.call();
    final matches = [
      for (final profile in profiles)
        if (expectedKind == null || profile.kind == expectedKind) profile,
    ];
    availableProfiles(matches);
    await _restorePinnedProfile();
    final pinned = matches.where(
      (profile) =>
          profile.actorId == _pinnedActorId &&
          profile.schoolId == _pinnedSchoolId,
    );
    if (pinned.length == 1) {
      _pinnedActorKind = pinned.single.kind;
      return;
    }
    _pinnedActorId = null;
    _pinnedSchoolId = null;
    _pinnedActorKind = null;
    if (matches.length == 1 || (selectFirstProfile && matches.isNotEmpty)) {
      matches.sort((a, b) => a.schoolName.compareTo(b.schoolName));
      _pinnedActorId = matches.first.actorId;
      _pinnedSchoolId = matches.first.schoolId;
      _pinnedActorKind = matches.first.kind;
      await _persistPinnedProfile();
    }
  }

  Future<void> _restorePinnedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _pinnedActorId ??= prefs.getString('${_prefix}edaya_selected_actor_id');
    _pinnedSchoolId ??= prefs.getString('${_prefix}edaya_selected_school_id');
    _pinnedActorKind ??= prefs.getString('${_prefix}edaya_selected_actor_kind');
  }

  Future<void> _persistPinnedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pinnedActorId == null || _pinnedSchoolId == null) {
      await prefs.remove('${_prefix}edaya_selected_actor_id');
      await prefs.remove('${_prefix}edaya_selected_school_id');
      await prefs.remove('${_prefix}edaya_selected_actor_kind');
      return;
    }
    await prefs.setString('${_prefix}edaya_selected_actor_id', _pinnedActorId!);
    await prefs.setString(
      '${_prefix}edaya_selected_school_id',
      _pinnedSchoolId!,
    );
    await prefs.setString(
      '${_prefix}edaya_selected_actor_kind',
      _pinnedActorKind ?? '',
    );
  }

  Future<void> _clearLocalSession({bool persistCookies = true}) async {
    user(null);
    grants(null);
    availableProfiles(const []);
    _pinnedActorId = null;
    _pinnedSchoolId = null;
    _pinnedActorKind = null;
    _academicYearIdHeader = null;
    _actorKindHeader = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_prefix}edaya_selected_actor_id');
    await prefs.remove('${_prefix}edaya_selected_school_id');
    await prefs.remove('${_prefix}edaya_selected_actor_kind');
    if (persistCookies) {
      await _sessionStorage.clearCookies();
      _authClient.clearCredentials();
    }
  }
}

class SchoolAuthorizationProfile {
  const SchoolAuthorizationProfile({
    required this.kind,
    required this.actorId,
    required this.schoolId,
    required this.schoolName,
    required this.schoolShortName,
  });

  final String kind;
  final String actorId;
  final String schoolId;
  final String schoolName;
  final String schoolShortName;

  String get label => schoolShortName.isEmpty ? schoolName : schoolShortName;
}
