import 'attendance_label.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/session_category.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_mappers.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'models/logbook_entry.dart';
import 'session_detail_controller.dart';

HomeDayCategory _categoryForKind(String kind) {
  return switch (kind) {
    'activity' => HomeDayCategory.activity,
    'assessment' => HomeDayCategory.assessment,
    _ => HomeDayCategory.lesson,
  };
}

class SessionDetailPage extends StatelessWidget {
  const SessionDetailPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveSessionDetailPage(sessionId: sessionId);
    }
    return _MockSessionDetailPage(sessionId: sessionId);
  }
}

class _MockSessionDetailPage extends LScopedView<StoreBoundController> {
  const _MockSessionDetailPage({required this.sessionId});

  final String sessionId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final session = controller.store.sessionById(sessionId);
    if (session == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/calendar',
        title: context.tr.session,
        body: EmptyState(title: context.tr.sessionNotFound),
      );
    }

    final category = session.category;
    final textTheme = Theme.of(context).textTheme;
    final logbook = controller.store.logbookForSession(sessionId);
    final assessment = controller.store.assessmentForSession(sessionId);
    final activity = controller.store.activityForSession(sessionId);

    return PrototypeDetailScaffold(
      fallbackRoute: '/calendar',
      titleWidget: Row(
        children: [
          SessionCategoryIcon(category: category, size: 18, padding: 6),
          const SizedBox(width: PrototypeSpacing.xs),
          Expanded(
            child: Text(session.subject, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(session.subject, style: textTheme.titleLarge),
          const SizedBox(height: PrototypeSpacing.xs),
          Text(
            DateFormat.yMMMMEEEEd(context.tr.localeName).format(session.date),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(
                      label: switch (category) {
                        HomeDayCategory.lesson =>
                          context.tr.timetableSessionKindLesson,
                        HomeDayCategory.activity =>
                          context.tr.timetableSessionKindActivity,
                        HomeDayCategory.assessment =>
                          context.tr.timetableSessionKindAssessment,
                      },
                      tone: switch (category) {
                        HomeDayCategory.lesson => SemanticTone.info,
                        HomeDayCategory.activity => SemanticTone.neutral,
                        HomeDayCategory.assessment => SemanticTone.warning,
                      },
                    ),
                    const Spacer(),
                    StatusChip(
                      label: attendanceLabel(context.tr, session.attendance),
                      tone: switch (session.attendance) {
                        'Absent' => SemanticTone.error,
                        'Retard' => SemanticTone.warning,
                        _ => SemanticTone.success,
                      },
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                Text(context.tr.schedule, style: textTheme.labelSmall),
                Text(
                  '${session.startHour.toString().padLeft(2, '0')}:00 – ${session.endHour.toString().padLeft(2, '0')}:00',
                ),
                if (session.room.isNotEmpty) ...[
                  const SizedBox(height: PrototypeSpacing.xs),
                  Text(session.room, style: textTheme.bodySmall),
                ],
                if (session.teacher.isNotEmpty) ...[
                  const SizedBox(height: PrototypeSpacing.xs),
                  Text(session.teacher, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          switch (category) {
            HomeDayCategory.assessment => _MockAssessmentSection(
              assessment: assessment,
            ),
            HomeDayCategory.activity => _MockActivitySection(
              activity: activity,
            ),
            HomeDayCategory.lesson => _LessonSection(
              logbook: logbook == null ? null : logbookEntryFromMock(logbook),
            ),
          },
        ],
      ),
    );
  }
}

class _MockAssessmentSection extends StatelessWidget {
  const _MockAssessmentSection({required this.assessment});

  final MockAssessmentDetail? assessment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (assessment == null) {
      return SurfaceCard(
        child: Text(
          context.tr.noDetailsAvailableForThisAssessment,
          style: textTheme.bodyMedium,
        ),
      );
    }
    final score = assessment!.score;
    final maxScore = assessment!.maxScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: context.tr.timetableSessionKindAssessment),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assessment!.title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (assessment!.description.isNotEmpty) ...[
                const SizedBox(height: PrototypeSpacing.sm),
                Text(assessment!.description, style: textTheme.bodyMedium),
              ],
              if (assessment!.instructions.isNotEmpty) ...[
                const SizedBox(height: PrototypeSpacing.sm),
                Text(context.tr.instructions, style: textTheme.labelSmall),
                Text(assessment!.instructions, style: textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (score != null && maxScore != null) ...[
          const SizedBox(height: PrototypeSpacing.md),
          SectionHeader(title: context.tr.studentSMark),
          SurfaceCard(
            child: Text(
              '${formatGradeNumber(score)}/${formatGradeNumber(maxScore)}',
              style: textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MockActivitySection extends StatelessWidget {
  const _MockActivitySection({required this.activity});

  final MockActivityDetail? activity;

  @override
  Widget build(BuildContext context) {
    final notes = activity?.staffComment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: context.tr.staffComment),
        SurfaceCard(
          child: Text(
            (notes == null || notes.isEmpty)
                ? context.tr.noCommentHasBeenSharedForThisActivity
                : notes,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _LiveSessionDetailPage extends LScopedView<SessionDetailController> {
  const _LiveSessionDetailPage({required this.sessionId});

  final String sessionId;

  @override
  SessionDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SessionDetailController(
        sessionId: sessionId,
        studentContext: scope.find<StudentContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SessionDetailController controller) {
    if (controller.isBusy.value && controller.session.value == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/calendar',
        title: context.tr.session,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final session = controller.session.value;
    if (session == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/calendar',
        title: context.tr.session,
        body: EmptyState(
          title: controller.errorMessage.value.isEmpty
              ? context.tr.sessionNotFound
              : controller.errorMessage.value,
        ),
      );
    }

    final category = _categoryForKind(session.kind);
    final label = attendanceLabel(
      context.tr,
      controller.attendance.value?.status,
    );
    final textTheme = Theme.of(context).textTheme;
    final timeFmt = AppDateFormatting.clockFormat(
      context.appSettings.timeFormat.value,
      context.tr.localeName,
    );

    return PrototypeDetailScaffold(
      fallbackRoute: '/calendar',
      titleWidget: Row(
        children: [
          SessionCategoryIcon(category: category, size: 18, padding: 6),
          const SizedBox(width: PrototypeSpacing.xs),
          Expanded(
            child: Text(
              session.subjectLabel ?? session.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(
            session.subjectLabel ?? session.title,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: PrototypeSpacing.xs),
          Text(
            DateFormat.yMMMMEEEEd(
              context.tr.localeName,
            ).format(session.startsAt),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(
                      label: switch (category) {
                        HomeDayCategory.lesson =>
                          context.tr.timetableSessionKindLesson,
                        HomeDayCategory.activity =>
                          context.tr.timetableSessionKindActivity,
                        HomeDayCategory.assessment =>
                          context.tr.timetableSessionKindAssessment,
                      },
                      tone: switch (category) {
                        HomeDayCategory.lesson => SemanticTone.info,
                        HomeDayCategory.activity => SemanticTone.neutral,
                        HomeDayCategory.assessment => SemanticTone.warning,
                      },
                    ),
                    const Spacer(),
                    StatusChip(
                      label: label,
                      tone: switch (controller.attendance.value?.status) {
                        'absent' => SemanticTone.error,
                        'late' => SemanticTone.warning,
                        null => SemanticTone.neutral,
                        _ => SemanticTone.success,
                      },
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                Text(context.tr.schedule, style: textTheme.labelSmall),
                Text(
                  '${timeFmt.format(session.startsAt)} – ${timeFmt.format(session.endsAt)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          switch (session.kind) {
            'assessment' => _AssessmentSection(controller: controller),
            'activity' => _ActivitySection(controller: controller),
            _ => _LessonSection(logbook: controller.logbook.value),
          },
        ],
      ),
    );
  }
}

class _LessonSection extends StatelessWidget {
  const _LessonSection({required this.logbook});

  final LogbookEntry? logbook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: context.tr.logbook),
        SurfaceCard(
          child: logbook == null
              ? Text(
                  context.tr.noLogbookEntryForSession,
                  style: textTheme.bodyMedium,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      logbook!.chapter,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: PrototypeSpacing.xs),
                    Text(logbook!.content, style: textTheme.bodyMedium),
                    const SizedBox(height: PrototypeSpacing.xs),
                    for (final chapter in logbook!.chapters) ...[
                      Text(
                        '${chapter.name} · ${chapter.completed == null
                            ? context.tr.logbookReference
                            : chapter.completed!
                            ? context.tr.logbookFinishedHere
                            : context.tr.logbookCovered}',
                      ),
                      if (chapter.notes != null) Text(chapter.notes!),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _AssessmentSection extends StatelessWidget {
  const _AssessmentSection({required this.controller});

  final SessionDetailController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = controller.assessmentTitle.value;
    if (title == null) {
      return SurfaceCard(
        child: Text(
          context.tr.noDetailsAvailableForThisAssessment,
          style: textTheme.bodyMedium,
        ),
      );
    }

    final score = controller.assessmentScore.value;
    final maxScore = controller.assessmentMaxScore.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: context.tr.timetableSessionKindAssessment),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((controller.assessmentDescription.value ?? '')
                  .isNotEmpty) ...[
                const SizedBox(height: PrototypeSpacing.sm),
                Text(
                  controller.assessmentDescription.value!,
                  style: textTheme.bodyMedium,
                ),
              ],
              if ((controller.assessmentInstructions.value ?? '')
                  .isNotEmpty) ...[
                const SizedBox(height: PrototypeSpacing.sm),
                Text(context.tr.instructions, style: textTheme.labelSmall),
                Text(
                  controller.assessmentInstructions.value!,
                  style: textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (controller.assessmentMention.value != null)
          SurfaceCard(
            child: Text(
              controller.assessmentMention.value!,
              style: textTheme.titleLarge,
            ),
          ),
        if (score != null && maxScore != null) ...[
          const SizedBox(height: PrototypeSpacing.md),
          SectionHeader(title: context.tr.studentSMark),
          SurfaceCard(
            child: Text(
              '${formatGradeNumber(score)}/${formatGradeNumber(maxScore)}',
              style: textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.controller});

  final SessionDetailController controller;

  @override
  Widget build(BuildContext context) {
    final notes =
        controller.activityNotes.value ?? controller.logbook.value?.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: context.tr.staffComment),
        SurfaceCard(
          child: Text(
            (notes == null || notes.isEmpty)
                ? context.tr.noCommentHasBeenSharedForThisActivity
                : notes,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
