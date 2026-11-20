import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'invitation_controller.dart';

class InvitationPage extends LScopedView<InvitationController> {
  const InvitationPage({
    super.key,
    required this.token,
    required this.onAccepted,
    required this.onContinueToLogin,
  });

  final String token;
  final Future<void> Function() onAccepted;
  final Future<void> Function() onContinueToLogin;

  @override
  InvitationController onConfigScope(LevitScope scope) {
    return scope.put(
      () => InvitationController(
        token: token,
        session: scope.find<AppSessionController>(),
        pendingInvitation: scope.find<PendingInvitationStore>(),
        schoolClient: scope.find<SchoolClientFactory>(),
        onAccepted: onAccepted,
        onContinueToLogin: onContinueToLogin,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, InvitationController controller) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.invitationTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: LWatch(() {
                  final session = context.levit.find<AppSessionController>();
                  final signedIn = session.user.value != null;
                  session.grants.value;
                  final preview = controller.preview.value;
                  final status = controller.loadStatus.value;
                  final message = controller.errorMessage.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: EdayaBrandLogo(
                          variant: EdayaLogoVariant.vertical,
                          width: 112,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.tr.invitationTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (status == DataStatus.loading)
                        const Center(child: CircularProgressIndicator())
                      else if (preview != null) ...[
                        Text(
                          context.tr.invitationSummary(
                            preview.inviteeName,
                            preview.schoolName,
                          ),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (DateTime.tryParse(preview.expiresAt ?? '')
                            case final expiry?) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.tr.invitationExpires(
                              '${context.formatShortDate(expiry)} · ${context.formatTimeOfDay(expiry)}',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          message,
                          style: TextStyle(
                            color:
                                preview != null &&
                                    preview.isGuardian &&
                                    preview.isPending
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (controller.wrongSchoolAccount)
                        FilledButton(
                          onPressed: controller.isBusy.value
                              ? null
                              : controller.switchAccount,
                          child: Text(context.tr.invitationSignOutSwitch),
                        )
                      else if (preview != null &&
                          preview.isGuardian &&
                          preview.isPending)
                        FilledButton(
                          onPressed: controller.isBusy.value
                              ? null
                              : signedIn
                              ? controller.accept
                              : controller.continueToLogin,
                          child: controller.isBusy.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  signedIn
                                      ? context.tr.invitationAcceptCta
                                      : context.tr.invitationContinue,
                                ),
                        )
                      else if (status != DataStatus.loading)
                        FilledButton(
                          onPressed: controller.isBusy.value
                              ? null
                              : controller.dismiss,
                          child: Text(context.tr.invitationContinue),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
