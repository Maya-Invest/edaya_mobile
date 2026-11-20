import 'dart:async';
import 'dart:typed_data';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/school_client.dart';
import '../../api/mutation_feedback.dart';
import '../../common/widgets/data_state.dart';
import '../../l10n/l10n_lookup.dart';
import '../auth/app_session_controller.dart';
import '../profile_photo/profile_photo_upload.dart';
import 'account_profile_data.dart';
import 'account_profile_models.dart';

class AccountProfileController extends LevitController
    with LevitReactiveTasksMixin {
  AccountProfileController({
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
    this.onProfileSaved,
  }) : _session = session,
       _schoolClient = schoolClient;

  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;
  final Future<void> Function(AccountContactProfile profile)? onProfileSaved;

  final profile = LxVar<AccountContactProfile?>(null);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');
  final isSaving = LxVar(false);
  final formRevision = LxVar(0);

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final alternativePhoneController = TextEditingController();
  final emailNotificationsEnabled = LxVar(true);
  final smsNotificationsEnabled = LxVar(true);
  final pushNotificationsEnabled = LxVar(true);
  bool _closed = false;
  int _loadGeneration = 0;
  String get _identity =>
      "${_session.grants.value?.schoolId}:$profileKind:$actorId";

  @override
  void onInit() {
    super.onInit();
    autoDispose(profile);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(isSaving);
    autoDispose(formRevision);
    autoDispose(emailNotificationsEnabled);
    autoDispose(smsNotificationsEnabled);
    autoDispose(pushNotificationsEnabled);
    unawaited(loadProfile());
  }

  @override
  void onClose() {
    _closed = true;
    _loadGeneration++;
    alternativePhoneController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  String? get profileKind => _session.grants.value?.kind;

  String? get actorId => _session.grants.value?.actorId;

  bool get isGuardian => profileKind == 'guardian';

  bool get showsPhoneField =>
      profileKind == 'guardian' || profileKind == 'teacher';

  String? get loginEmail => _session.user.value?.email;

  bool get canUploadPhoto =>
      profileKind == 'guardian' || profileKind == 'staff';

  bool get canSave {
    formRevision.value;
    return (profileKind == 'guardian' ||
            firstNameController.text.trim().isNotEmpty) &&
        lastNameController.text.trim().isNotEmpty &&
        profile.value?.id == actorId &&
        !isSaving.value;
  }

  bool get isDirty {
    formRevision.value;
    final current = profile.value;
    if (current == null) return false;
    return (!isGuardian &&
            (firstNameController.text.trim() != current.firstName ||
                lastNameController.text.trim() != current.lastName)) ||
        emailController.text.trim() != (current.email ?? '') ||
        phoneController.text.trim() != (current.phone ?? '') ||
        (isGuardian &&
            (alternativePhoneController.text.trim() !=
                    (current.alternativePhone ?? '') ||
                emailNotificationsEnabled.value !=
                    current.emailNotificationsEnabled ||
                smsNotificationsEnabled.value !=
                    current.smsNotificationsEnabled ||
                pushNotificationsEnabled.value !=
                    current.pushNotificationsEnabled));
  }

  void discardChanges() {
    final current = profile.value;
    if (current != null) _bindForm(current);
    markFormChanged();
  }

  void markFormChanged() {
    formRevision(formRevision.value + 1);
  }

  DataStatus get dataStatus {
    if (isBusy.value && profile.value == null) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && profile.value == null) {
      return DataStatus.error;
    }
    if (profile.value == null) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  Future<void> loadProfile() async {
    final kind = profileKind;
    final id = actorId;
    final identity = _identity;
    final generation = ++_loadGeneration;
    if (kind == null || id == null) {
      errorMessage(systemL10n().accountProfileUnavailable);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final loaded = await loadAccountContactProfile(
          _schoolClient(),
          kind: kind,
          actorId: id,
        );
        if (_closed || identity != _identity || generation != _loadGeneration)
          return;
        profile(loaded);
        _bindForm(loaded);
      } on api.ApiError catch (error) {
        if (!_closed && identity == _identity && generation == _loadGeneration)
          errorMessage(systemL10n().accountProfileLoadError('$error'));
      } on Object catch (error) {
        if (!_closed && identity == _identity && generation == _loadGeneration)
          errorMessage(systemL10n().accountProfileLoadError('$error'));
      }
    });
  }

  Future<bool> publishOwnPortrait(Uint8List jpegBytes) async {
    final kind = profileKind;
    final current = profile.value;
    final schoolId = _session.grants.value?.schoolId;
    if (kind == null ||
        current == null ||
        schoolId == null ||
        !canUploadPhoto) {
      return false;
    }

    final identity = _identity;
    saveMessage('');
    isSaving(true);
    try {
      final uploaded = await uploadProfilePhoto(
        client: _schoolClient(),
        schoolId: schoolId,
        ownerKind: kind,
        ownerId: current.id,
        jpegBytes: jpegBytes,
      );
      final updated = current.copyWith(photoUrl: uploaded.photoUrl);
      if (kind == 'guardian') {
        await _schoolClient().updateGuardianProfile({
          'guardianId': current.id,
          'photoUrl': uploaded.photoUrl,
        });
      } else {
        await saveAccountContactProfile(
          _schoolClient(),
          kind: kind,
          profile: updated,
        );
      }
      if (_closed || identity != _identity) return false;
      profile(updated);
      saveMessage(systemL10n().profilePhotoUpdateSuccess);
      return true;
    } on api.ApiError catch (error) {
      if (_closed || identity != _identity) return false;
      saveMessage(
        mutationFailureMessage(
          error,
          systemL10n().profilePhotoUpdateError('$error'),
        ),
      );
      return false;
    } on Object catch (error) {
      if (_closed || identity != _identity) return false;
      saveMessage(
        mutationFailureMessage(
          error,
          systemL10n().profilePhotoUpdateError('$error'),
        ),
      );
      return false;
    } finally {
      if (!_closed) isSaving(false);
    }
  }

  Future<bool> saveProfile() async {
    final kind = profileKind;
    final current = profile.value;
    if (kind == null || current == null || !canSave) {
      return false;
    }

    final identity = _identity;
    saveMessage('');
    isSaving(true);
    try {
      final updated = AccountContactProfile(
        id: current.id,
        firstName: isGuardian
            ? current.firstName
            : firstNameController.text.trim(),
        lastName: isGuardian
            ? current.lastName
            : lastNameController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        phone: showsPhoneField && phoneController.text.trim().isNotEmpty
            ? phoneController.text.trim()
            : null,
        alternativePhone: alternativePhoneController.text.trim().isEmpty
            ? null
            : alternativePhoneController.text.trim(),
        emailNotificationsEnabled: emailNotificationsEnabled.value,
        smsNotificationsEnabled: smsNotificationsEnabled.value,
        pushNotificationsEnabled: pushNotificationsEnabled.value,
        photoUrl: current.photoUrl,
        hasAccess: current.hasAccess,
      );

      await saveAccountContactProfile(
        _schoolClient(),
        kind: kind,
        profile: updated,
      );
      if (_closed || identity != _identity) return false;
      profile(updated);
      saveMessage(systemL10n().accountProfileUpdateSuccess);
      await refreshAfterMutation(() async {
        await onProfileSaved?.call(updated);
      }, showWarning: (message) => saveMessage(message));
      return true;
    } on api.ApiError catch (error) {
      if (_closed || identity != _identity) return false;
      saveMessage(
        mutationFailureMessage(
          error,
          systemL10n().accountProfileSaveError('$error'),
        ),
      );
      return false;
    } on Object catch (error) {
      if (_closed || identity != _identity) return false;
      saveMessage(
        mutationFailureMessage(
          error,
          systemL10n().accountProfileSaveError('$error'),
        ),
      );
      return false;
    } finally {
      if (!_closed) isSaving(false);
    }
  }

  void _bindForm(AccountContactProfile loaded) {
    firstNameController.text = loaded.firstName;
    lastNameController.text = loaded.lastName;
    emailController.text = loaded.email ?? '';
    phoneController.text = loaded.phone ?? '';
    alternativePhoneController.text = loaded.alternativePhone ?? '';
    emailNotificationsEnabled(loaded.emailNotificationsEnabled);
    smsNotificationsEnabled(loaded.smsNotificationsEnabled);
    pushNotificationsEnabled(loaded.pushNotificationsEnabled);
  }
}
