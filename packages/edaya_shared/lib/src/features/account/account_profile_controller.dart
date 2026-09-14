import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/school_client.dart';
import '../../api/mutation_feedback.dart';
import '../../common/widgets/data_state.dart';
import '../../l10n/l10n_lookup.dart';
import '../auth/app_session_controller.dart';
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

  @override
  void onInit() {
    super.onInit();
    autoDispose(profile);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(isSaving);
    autoDispose(formRevision);
    unawaited(loadProfile());
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  String? get profileKind => _session.grants.value?.kind;

  String? get actorId => _session.grants.value?.actorId;

  bool get showsPhoneField => profileKind == 'guardian';

  String? get loginEmail => _session.user.value?.email;

  bool get canSave {
    formRevision.value;
    return firstNameController.text.trim().isNotEmpty &&
        lastNameController.text.trim().isNotEmpty &&
        !isSaving.value;
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
        profile(loaded);
        _bindForm(loaded);
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().accountProfileLoadError('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().accountProfileLoadError('$error'));
      }
    });
  }

  Future<bool> saveProfile() async {
    final kind = profileKind;
    final current = profile.value;
    if (kind == null || current == null || !canSave) {
      return false;
    }

    saveMessage('');
    isSaving(true);
    try {
      final updated = AccountContactProfile(
        id: current.id,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        phone: showsPhoneField && phoneController.text.trim().isNotEmpty
            ? phoneController.text.trim()
            : null,
        photoUrl: current.photoUrl,
        hasAccess: current.hasAccess,
      );

      await saveAccountContactProfile(
        _schoolClient(),
        kind: kind,
        profile: updated,
      );
      profile(updated);
      saveMessage(systemL10n().accountProfileUpdateSuccess);
      await refreshAfterMutation(() async {
        await onProfileSaved?.call(updated);
      }, showWarning: (message) => saveMessage(message));
      return true;
    } on api.ApiError catch (error) {
      saveMessage(
        mutationFailureMessage(
          error,
          systemL10n().accountProfileSaveError('$error'),
        ),
      );
      return false;
    } on Object catch (error) {
      saveMessage(
        mutationFailureMessage(
          error,
          systemL10n().accountProfileSaveError('$error'),
        ),
      );
      return false;
    } finally {
      isSaving(false);
    }
  }

  void _bindForm(AccountContactProfile loaded) {
    firstNameController.text = loaded.firstName;
    lastNameController.text = loaded.lastName;
    emailController.text = loaded.email ?? '';
    phoneController.text = loaded.phone ?? '';
  }
}
