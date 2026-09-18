import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'waiting_for_students_controller.dart';

class WaitingForStudentsPage extends LScopedView<WaitingForStudentsController> {
  const WaitingForStudentsPage({super.key, required this.onCheckAgain});

  final Future<void> Function() onCheckAgain;

  @override
  WaitingForStudentsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => WaitingForStudentsController(
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
        onCheckAgain: onCheckAgain,
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    WaitingForStudentsController controller,
  ) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.appTitleGuardian)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LWatch(() {
                  final session = context.levit.find<AppSessionController>();
                  final busy =
                      controller.isBusy.value || session.isSigningOut.value;
                  final pending = controller.invitations.value;
                  final status = controller.loadStatus.value;
                  final message = controller.errorMessage.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'edaya',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.tr.waitingForStudentsTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr.waitingForStudentsBody,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (status == DataStatus.loading && pending.isEmpty) ...[
                        const SizedBox(height: 24),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      if (pending.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          context.tr.waitingPendingInvitationsTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        for (final invitation in pending)
                          _PendingInvitationCard(
                            invitation: invitation,
                            busy: busy,
                            accepting:
                                controller.acceptingId.value == invitation.id,
                            onAccept: () => controller.accept(invitation),
                          ),
                      ] else if (status == DataStatus.empty) ...[
                        const SizedBox(height: 16),
                        Text(
                          context.tr.waitingNoPendingInvitations,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: busy ? null : controller.checkAgain,
                        child: busy && controller.acceptingId.value == null
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.tr.waitingForStudentsCheckAgain),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: busy ? null : controller.signOut,
                        child: Text(context.tr.signOut),
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

class _PendingInvitationCard extends StatelessWidget {
  const _PendingInvitationCard({
    required this.invitation,
    required this.busy,
    required this.accepting,
    required this.onAccept,
  });

  final PendingSessionInvitation invitation;
  final bool busy;
  final bool accepting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr.invitationSummary(
                  invitation.inviteeName,
                  invitation.schoolName,
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (invitation.expiresAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr.invitationExpires(invitation.expiresAt!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : onAccept,
                child: accepting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr.invitationAcceptCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
