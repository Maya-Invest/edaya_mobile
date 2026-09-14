import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/school_client.dart';
import '../../common/widgets/data_state.dart';
import '../../l10n/l10n_extension.dart';
import '../../ui/person_avatar.dart';
import '../auth/app_session_controller.dart';
import 'account_profile_controller.dart';
import 'account_profile_models.dart';

class AccountProfilePage extends LScopedView<AccountProfileController> {
  const AccountProfilePage({
    super.key,
    required this.session,
    required this.schoolClient,
    this.onProfileSaved,
  });

  final AppSessionController session;
  final SchoolClientFactory schoolClient;
  final Future<void> Function(AccountContactProfile profile)? onProfileSaved;

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
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.accountProfileTitle)),
      body: LWatch(
        () => DataState(
          status: controller.dataStatus,
          errorMessage: controller.errorMessage.value,
          emptyMessage: context.tr.accountProfileUnavailable,
          onRetry: controller.loadProfile,
          child: LWatch(() => _ProfileForm(controller: controller)),
        ),
      ),
    );
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({required this.controller});

  final AccountProfileController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile.value;
    if (profile == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Center(
          child: PersonAvatar(
            name: profile.fullName,
            initials: profile.initials,
            photoUrl: profile.photoUrl,
            radius: 40,
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
          controller: controller.firstNameController,
          decoration: InputDecoration(labelText: context.tr.firstNameLabel),
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          onChanged: (_) => controller.markFormChanged(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.lastNameController,
          decoration: InputDecoration(labelText: context.tr.lastNameLabel),
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.familyName],
          onChanged: (_) => controller.markFormChanged(),
        ),
        const SizedBox(height: 16),
        TextField(
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
            controller: controller.phoneController,
            decoration: InputDecoration(labelText: context.tr.phoneLabel),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => controller.markFormChanged(),
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
