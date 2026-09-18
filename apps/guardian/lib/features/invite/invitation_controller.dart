import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

class InvitationPreview {
  const InvitationPreview({
    required this.status,
    required this.kind,
    required this.targetId,
    required this.schoolName,
    required this.inviteeName,
    this.expiresAt,
    this.contactEmail,
  });

  factory InvitationPreview.fromJson(Map<String, dynamic> json) {
    return InvitationPreview(
      status: json['status'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      schoolName: json['schoolName'] as String? ?? '',
      inviteeName: json['inviteeName'] as String? ?? '',
      expiresAt: json['expiresAt'] as String?,
      contactEmail: json['contactEmail'] as String?,
    );
  }

  final String status;
  final String kind;
  final String targetId;
  final String schoolName;
  final String inviteeName;
  final String? expiresAt;
  final String? contactEmail;

  bool get isGuardian => kind == 'guardian';
  bool get isPending => status == 'pending';
}

class InvitationController extends LevitController
    with LevitReactiveTasksMixin {
  InvitationController({
    required this.token,
    required AppSessionController session,
    required PendingInvitationStore pendingInvitation,
    required SchoolClientFactory schoolClient,
    required Future<void> Function() onAccepted,
    required Future<void> Function() onContinueToLogin,
  }) : _session = session,
       _pendingInvitation = pendingInvitation,
       _schoolClient = schoolClient,
       _onAccepted = onAccepted,
       _onContinueToLogin = onContinueToLogin;

  final String token;
  final AppSessionController _session;
  final PendingInvitationStore _pendingInvitation;
  final SchoolClientFactory _schoolClient;
  final Future<void> Function() _onAccepted;
  final Future<void> Function() _onContinueToLogin;

  final preview = LxVar<InvitationPreview?>(null);
  final errorMessage = LxVar('');
  final loadStatus = LxVar(DataStatus.loading);

  bool get isAuthenticated => _session.isAuthenticated;

  bool get wrongSchoolAccount {
    final current = preview.value;
    final grants = _session.grants.value;
    if (current == null || grants == null) {
      return false;
    }
    if (grants.kind != 'guardian') {
      return true;
    }
    return grants.actorId != current.targetId;
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(preview);
    autoDispose(errorMessage);
    autoDispose(loadStatus);
    _pendingInvitation.remember(token);
    unawaited(loadPreview());
  }

  Future<void> loadPreview() async {
    errorMessage('');
    loadStatus(DataStatus.loading);
    await runTask(() async {
      try {
        final result = await _schoolClient().previewInvitation(token: token);
        final loaded = InvitationPreview.fromJson(result);
        preview(loaded);
        if (!loaded.isGuardian) {
          await _pendingInvitation.clear();
          errorMessage(systemL10n().invitationWrongKind);
          loadStatus(DataStatus.ready);
          return;
        }
        if (loaded.status == 'expired') {
          await _pendingInvitation.clear();
          errorMessage(systemL10n().invitationExpired);
        } else if (loaded.status == 'revoked') {
          await _pendingInvitation.clear();
          errorMessage(systemL10n().invitationRevoked);
        } else if (loaded.status == 'accepted') {
          await _pendingInvitation.clear();
          errorMessage(systemL10n().invitationAlreadyAccepted);
        } else if (!loaded.isPending) {
          await _pendingInvitation.clear();
          errorMessage(systemL10n().invitationInvalid);
        }
        loadStatus(DataStatus.ready);
      } on api.ApiError catch (error) {
        preview(null);
        if (error.status == 404) {
          await _pendingInvitation.clear();
          errorMessage(systemL10n().invitationNotFound);
        } else {
          errorMessage(systemL10n().invitationLoadError('$error'));
        }
        loadStatus(DataStatus.error);
      } on Object catch (error) {
        preview(null);
        errorMessage(systemL10n().invitationLoadError('$error'));
        loadStatus(DataStatus.error);
      }
    }, id: 'invitation-preview');
  }

  Future<void> continueToLogin() async {
    _pendingInvitation.remember(token);
    await _onContinueToLogin();
  }

  Future<void> dismiss() async {
    await _pendingInvitation.clear();
    if (_session.isAuthenticated) {
      await _onAccepted();
      return;
    }
    await _onContinueToLogin();
  }

  Future<void> switchAccount() async {
    errorMessage('');
    await runTask(() async {
      await _session.signOut();
      await _pendingInvitation.save(token);
      await _onContinueToLogin();
    }, id: 'invitation-switch-account');
  }

  Future<void> accept() async {
    final current = preview.value;
    if (current == null || !current.isGuardian || !current.isPending) {
      return;
    }
    if (!_session.isAuthenticated) {
      await continueToLogin();
      return;
    }
    if (wrongSchoolAccount) {
      errorMessage(systemL10n().invitationWrongAccount);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        await _schoolClient().acceptInvitation(token: token);
        final grantsError = await _session.refreshGrants();
        if (grantsError != null) {
          errorMessage(grantsError);
          return;
        }
        await _pendingInvitation.clear();
        await _onAccepted();
      } on api.ApiError catch (error) {
        final code = _errorCode(error);
        if (code == 'SUBJECT_ALREADY_LINKED') {
          errorMessage(systemL10n().invitationWrongAccount);
          return;
        }
        if (code == 'INVITATION_ALREADY_ACCEPTED') {
          errorMessage(systemL10n().invitationAlreadyAccepted);
          return;
        }
        errorMessage(systemL10n().invitationLoadError('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().invitationLoadError('$error'));
      }
    }, id: 'invitation-accept');
  }

  String? _errorCode(api.ApiError error) {
    final body = error.body;
    if (body is Map && body['code'] is String) {
      return body['code'] as String;
    }
    return null;
  }
}
