import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/student_context_controller.dart';
import 'child_profile_controller.dart';

class ChildProfilePage extends LScopedView<ChildProfileController> {
  const ChildProfilePage({super.key});

  @override
  ChildProfileController onConfigScope(LevitScope scope) {
    return scope.put(
      () => ChildProfileController(
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
        studentContext: scope.find<StudentContextController>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, ChildProfileController controller) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.childProfileTitle)),
      body: LWatch(
        () => DataState(
          status: controller.dataStatus,
          errorMessage: controller.errorMessage.value,
          emptyMessage: context.tr.childProfileUnavailable,
          onRetry: controller.load,
          child: LWatch(() => _ChildProfileBody(controller: controller)),
        ),
      ),
    );
  }
}

class _ChildProfileBody extends StatelessWidget {
  const _ChildProfileBody({required this.controller});

  final ChildProfileController controller;

  @override
  Widget build(BuildContext context) {
    final student = controller.student.value;
    if (student == null) {
      return const SizedBox.shrink();
    }
    final pending = controller.pending.value;
    final rejected = controller.latestRejected.value;
    final proposedUrl = controller.isSubmitter && pending != null
        ? profilePhotoContentPath(pending['attachmentId'] as String)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(student.fullName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        Text(
          context.tr.childProfilePublished,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        PersonAvatar(
          name: student.fullName,
          initials: student.initials,
          photoUrl: student.photoUrl,
          radius: 48,
        ),
        if (student.photoUrl == null) ...[
          const SizedBox(height: 8),
          Text(context.tr.childProfileNoPublished),
        ],
        const SizedBox(height: 24),
        Text(
          context.tr.childProfileProposed,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        if (pending != null) ...[
          if (proposedUrl != null)
            PersonAvatar(
              name: student.fullName,
              initials: student.initials,
              photoUrl: proposedUrl,
              radius: 48,
            )
          else
            Text(context.tr.childProfilePendingIndicator),
          const SizedBox(height: 12),
          Text(context.tr.childProfilePending),
          if (controller.isSubmitter) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: controller.isSaving.value
                  ? null
                  : () => controller.withdrawPending(),
              child: Text(context.tr.childProfileWithdraw),
            ),
          ],
        ] else if (rejected != null &&
            rejected['submitterGuardianId'] == controller.guardianId) ...[
          Text(
            context.tr.childProfileRejected(
              (rejected['rejectionReason'] as String?)?.trim().isNotEmpty ==
                      true
                  ? rejected['rejectionReason'] as String
                  : context.tr.childProfileRejectedNoReason,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: controller.isSaving.value
                ? null
                : () => _pickAndSubmit(context),
            child: Text(context.tr.childProfileResubmit),
          ),
        ] else ...[
          Text(context.tr.childProfileSubmitHint),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: controller.isSaving.value
                ? null
                : () => _pickAndSubmit(context),
            child: Text(context.tr.childProfileSubmit),
          ),
        ],
        if (controller.statusMessage.value.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(controller.statusMessage.value),
        ],
        if (controller.isSaving.value) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Future<void> _pickAndSubmit(BuildContext context) async {
    final jpeg = await pickAndCropProfilePhoto(context);
    if (jpeg == null || !context.mounted) {
      return;
    }
    await controller.submitPortrait(jpeg);
  }
}
