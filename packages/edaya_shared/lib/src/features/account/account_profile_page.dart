import '../auth/account_security_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/school_client.dart';
import '../../common/widgets/data_state.dart';
import '../../l10n/l10n_extension.dart';
import '../../ui/person_avatar.dart';
import '../auth/app_session_controller.dart';
import '../profile_photo/profile_photo_flow.dart';
import 'account_profile_controller.dart';
import 'account_profile_models.dart';

class AccountProfilePage extends LScopedView<AccountProfileController> {
  const AccountProfilePage({
    super.key,
    required this.session,
    required this.schoolClient,
    this.onProfileSaved,
    this.embedded = false,
    this.profileActions,
    this.onOpenSecurity,
    this.confirmDiscard,
    this.onClose,
  });

  final AppSessionController session;
  final SchoolClientFactory schoolClient;
  final Future<void> Function(AccountContactProfile profile)? onProfileSaved;
  final bool embedded;

  /// Additional actions owned by the selected portal app.
  final Widget? profileActions;

  /// Optional app-owned presentation for security details.
  final VoidCallback? onOpenSecurity;

  /// Optional app-owned discard confirmation.
  final Future<bool?> Function(BuildContext)? confirmDiscard;
  final VoidCallback? onClose;

  @override
  AccountProfileController onConfigScope(LevitScope scope) {
    return scope.put(
      () => AccountProfileController(
        session: session,
        schoolClient: schoolClient,
        onProfileSaved: onProfileSaved,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, AccountProfileController controller) {
    final body = LWatch(
      () => DataState(
        status: controller.dataStatus,
        errorMessage: controller.errorMessage.value,
        emptyMessage: context.tr.accountProfileUnavailable,
        onRetry: controller.loadProfile,
        child: LWatch(
          () => _ProfileForm(
            controller: controller,
            profileActions: profileActions,
            onOpenSecurity: onOpenSecurity,
          ),
        ),
      ),
    );
    final guardedBody = LWatch(
      () => PopScope(
        canPop: !controller.isDirty && !controller.isSaving.value,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || controller.isSaving.value) return;
          final discard =
              await (confirmDiscard?.call(context) ??
                  showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(context.tr.guardianDiscardChanges),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(
                            MaterialLocalizations.of(context).cancelButtonLabel,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: Text(context.tr.guardianDiscard),
                        ),
                      ],
                    ),
                  ));
          if (discard == true && context.mounted) {
            controller.discardChanges();
            await WidgetsBinding.instance.endOfFrame;
            if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
              if (onClose != null) {
                onClose!();
              } else {
                Navigator.of(context).pop();
              }
            }
          }
        },
        child: body,
      ),
    );
    if (embedded) return guardedBody;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.accountProfileTitle)),
      body: guardedBody,
    );
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.controller,
    this.profileActions,
    this.onOpenSecurity,
  });

  final AccountProfileController controller;
  final Widget? profileActions;
  final VoidCallback? onOpenSecurity;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile.value;
    if (profile == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        ?profileActions,
        ListTile(
          title: Text(context.tr.accountSecurity),
          leading: const Icon(Icons.security),
          onTap:
              onOpenSecurity ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccountSecurityPage(),
                ),
              ),
        ),
        Center(
          child: Tooltip(
            message: context.tr.profilePhotoCropTitle,
            child: GestureDetector(
              onTap: controller.canUploadPhoto && !controller.isSaving.value
                  ? () async {
                      final jpeg = await pickAndCropProfilePhoto(context);
                      if (jpeg == null || !context.mounted) {
                        return;
                      }
                      await controller.publishOwnPortrait(jpeg);
                    }
                  : null,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  PersonAvatar(
                    name: profile.fullName,
                    initials: profile.initials,
                    photoUrl: profile.photoUrl,
                    radius: 40,
                  ),
                  if (controller.canUploadPhoto)
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.tr.accountProfileDescription,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (controller.loginEmail != null) ...[
          const SizedBox(height: 12),
          Text(
            context.tr.accountProfileLoginEmail(controller.loginEmail!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          enabled: !controller.isSaving.value,
          controller: controller.firstNameController,
          readOnly: controller.isGuardian,
          decoration: InputDecoration(labelText: context.tr.firstNameLabel),
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          onChanged: (_) => controller.markFormChanged(),
        ),
        const SizedBox(height: 16),
        TextField(
          enabled: !controller.isSaving.value,
          controller: controller.lastNameController,
          readOnly: controller.isGuardian,
          decoration: InputDecoration(labelText: context.tr.lastNameLabel),
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.familyName],
          onChanged: (_) => controller.markFormChanged(),
        ),
        const SizedBox(height: 16),
        TextField(
          enabled: !controller.isSaving.value,
          controller: controller.emailController,
          decoration: InputDecoration(labelText: context.tr.emailLabel),
          keyboardType: TextInputType.emailAddress,
          textInputAction: controller.showsPhoneField
              ? TextInputAction.next
              : TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => controller.markFormChanged(),
        ),
        if (controller.showsPhoneField) ...[
          const SizedBox(height: 16),
          TextField(
            enabled: !controller.isSaving.value,
            controller: controller.phoneController,
            decoration: InputDecoration(
              labelText: controller.isGuardian
                  ? context.tr.guardianMainPhone
                  : context.tr.phoneLabel,
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => controller.markFormChanged(),
          ),
        ],
        if (controller.isGuardian) ...[
          const SizedBox(height: 16),
          TextField(
            enabled: !controller.isSaving.value,
            controller: controller.alternativePhoneController,
            decoration: InputDecoration(
              labelText: context.tr.guardianAlternativePhone,
            ),
            keyboardType: TextInputType.phone,
            onChanged: (_) => controller.markFormChanged(),
          ),
          const SizedBox(height: 16),
          Text(context.tr.guardianNotificationDestinations),
          SwitchListTile(
            title: Text(context.tr.guardianEmailNotifications),
            value: controller.emailNotificationsEnabled.value,
            onChanged: controller.isSaving.value
                ? null
                : (value) => controller.emailNotificationsEnabled(value),
          ),
          SwitchListTile(
            title: Text(context.tr.guardianSmsNotifications),
            value: controller.smsNotificationsEnabled.value,
            onChanged: controller.isSaving.value
                ? null
                : (value) => controller.smsNotificationsEnabled(value),
          ),
          SwitchListTile(
            title: Text(context.tr.guardianPushNotifications),
            value: controller.pushNotificationsEnabled.value,
            onChanged: controller.isSaving.value
                ? null
                : (value) => controller.pushNotificationsEnabled(value),
          ),
        ],
        if (controller.saveMessage.value.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            controller.saveMessage.value,
            style: TextStyle(
              color:
                  controller.saveMessage.value ==
                      context.tr.accountProfileUpdateSuccess
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: controller.canSave
              ? () async {
                  final saved = await controller.saveProfile();
                  if (saved && context.mounted) {
                    context.pop();
                  }
                }
              : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: controller.isSaving.value
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr.save),
        ),
      ],
    );
  }
}
