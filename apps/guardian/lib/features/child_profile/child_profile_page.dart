import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/shell_tabs.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'child_profile_controller.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../../app/guardian_words.dart';

class ChildProfilePage extends StatelessWidget {
  const ChildProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) return const _LiveChildProfilePage();
    final student = context.levit.find<MockStore>().activeStudent;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(student.fullName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        Text(
          words(
            context,
            'Photo et documents de l’enfant',
            'Child photo and documents',
          ),
        ),
      ],
    );
  }
}

class _LiveChildProfilePage extends LScopedView<ChildProfileController> {
  const _LiveChildProfilePage();

  @override
  ChildProfileController onConfigScope(LevitScope scope) {
    return scope.put(
      () => ChildProfileController(
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, ChildProfileController controller) {
    return LWatch(() {
      final hubPath = GuardianShellScope.maybeOf(context)?.hubPath ?? '/home';
      return PrototypeDetailScaffold(
        title: controller.student.value?.fullName ?? context.tr.studentProfile,
        fallbackRoute: hubPath,
        body: AdaptiveContent(
          child: DataState(
            status: controller.dataStatus,
            errorMessage: controller.errorMessage.value,
            emptyMessage: context.tr.childProfileUnavailable,
            onRetry: controller.load,
            child: LWatch(() => _ChildProfileBody(controller: controller)),
          ),
        ),
      );
    });
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
    final papers = controller.leftoverPapers.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(student.fullName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PrototypeSpacing.xl),
        SectionHeader(title: context.tr.photo),
        const SizedBox(height: PrototypeSpacing.sm),
        PersonAvatar(
          initials: student.initials,
          photoUrl: student.photoUrl,
          radius: 48,
        ),
        if (student.photoUrl == null) ...[
          const SizedBox(height: 8),
          Text(context.tr.childProfileNoPublished),
        ],
        const SizedBox(height: PrototypeSpacing.md),
        Text(
          context.tr.childProfileProposed,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        if (pending != null) ...[
          if (proposedUrl != null)
            PersonAvatar(
              initials: student.initials,
              photoUrl: proposedUrl,
              radius: 48,
            )
          else
            Text(context.tr.childProfilePendingIndicator),
          const SizedBox(height: 12),
          Text(context.tr.childProfilePending),
          if (controller.isSubmitter) ...[
            const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          FilledButton(
            onPressed: controller.isSaving.value
                ? null
                : () => _pickAndSubmit(context),
            child: Text(context.tr.childProfileResubmit),
          ),
        ] else ...[
          Text(context.tr.childProfileSubmitHint),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: controller.isSaving.value
                ? null
                : () => _pickAndSubmit(context),
            child: Text(context.tr.childProfileSubmit),
          ),
        ],
        if (controller.statusMessage.value.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(controller.statusMessage.value),
        ],
        if (controller.isSaving.value) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: PrototypeSpacing.xl),
        SectionHeader(title: context.tr.documents),
        const SizedBox(height: PrototypeSpacing.sm),
        if (papers.isEmpty)
          Text(
            words(
              context,
              'Aucun document scolaire pour cet élève.',
              'No school documents for this child.',
            ),
          )
        else
          for (final paper in papers) ...[
            ListRow(
              title: leftoverFamilyPaperLabel(paper.templateKey, context.tr),
              subtitle:
                  paper.number ?? documentStatusLabel(context.tr, paper.status),
              trailing: paper.isDownloadable
                  ? DocumentActionButton(
                      label: words(context, 'Ouvrir', 'Open'),
                      run: () => controller.downloadLeftover(paper),
                    )
                  : Text(documentStatusLabel(context.tr, paper.status)),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
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
