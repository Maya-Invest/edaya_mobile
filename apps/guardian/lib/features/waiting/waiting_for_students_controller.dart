import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

class PendingSessionInvitation {
  const PendingSessionInvitation({
    required this.id,
    required this.schoolName,
    required this.inviteeName,
    this.expiresAt,
  });

  factory PendingSessionInvitation.fromJson(Map<String, dynamic> json) {
    return PendingSessionInvitation(
      id: json['id'] as String? ?? '',
      schoolName: json['schoolName'] as String? ?? '',
      inviteeName: json['inviteeName'] as String? ?? '',
      expiresAt: json['expiresAt'] as String?,
    );
  }

  final String id;
  final String schoolName;
  final String inviteeName;
  final String? expiresAt;
}

class WaitingForStudentsController extends LevitController
    with LevitReactiveTasksMixin {
  WaitingForStudentsController({
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
    required Future<void> Function() onCheckAgain,
  }) : _session = session,
       _schoolClient = schoolClient,
       _onCheckAgain = onCheckAgain;

  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;
  final Future<void> Function() _onCheckAgain;

  final invitations = LxVar<List<PendingSessionInvitation>>(const []);
  final loadStatus = LxVar(DataStatus.loading);
  final errorMessage = LxVar('');
  final acceptingId = LxVar<String?>(null);

  @override
  void onInit() {
    super.onInit();
    autoDispose(invitations);
    autoDispose(loadStatus);
    autoDispose(errorMessage);
    autoDispose(acceptingId);
    unawaited(loadInvitations());
  }

  Future<void> checkAgain() {
    return runTask(() async {
      await loadInvitations();
      await _onCheckAgain();
    }, id: 'check-again');
  }

  Future<void> loadInvitations() async {
    errorMessage('');
    loadStatus(DataStatus.loading);
    try {
      final result = await _schoolClient().listMyInvitations();
      final raw = result['invitations'];
      final loaded = <PendingSessionInvitation>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            final invitation = PendingSessionInvitation.fromJson(item);
            if (invitation.id.isNotEmpty) {
              loaded.add(invitation);
            }
          } else if (item is Map) {
            final invitation = PendingSessionInvitation.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (invitation.id.isNotEmpty) {
              loaded.add(invitation);
            }
          }
        }
      }
      invitations(loaded);
      loadStatus(loaded.isEmpty ? DataStatus.empty : DataStatus.ready);
    } on api.ApiError catch (error) {
      invitations(const []);
      errorMessage(systemL10n().invitationLoadError('$error'));
      loadStatus(DataStatus.error);
    } on Object catch (error) {
      invitations(const []);
      errorMessage(systemL10n().invitationLoadError('$error'));
      loadStatus(DataStatus.error);
    }
  }

  Future<void> accept(PendingSessionInvitation invitation) {
    if (invitation.id.isEmpty) {
      return Future.value();
    }
    return runTask(() async {
      errorMessage('');
      acceptingId(invitation.id);
      try {
        await _schoolClient().acceptMyInvitation(invitationId: invitation.id);
        await loadInvitations();
        await _onCheckAgain();
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
      } finally {
        acceptingId(null);
      }
    }, id: 'accept-invitation');
  }

  Future<void> signOut() => _session.signOut();

  String? _errorCode(api.ApiError error) {
    final body = error.body;
    if (body is Map && body['code'] is String) {
      return body['code'] as String;
    }
    return null;
  }
}
