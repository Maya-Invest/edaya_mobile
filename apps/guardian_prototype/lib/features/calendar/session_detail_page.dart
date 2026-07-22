import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/session_category.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'session_detail_controller.dart';

class SessionDetailPage extends LScopedView<SessionDetailController> {
  const SessionDetailPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  SessionDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SessionDetailController(
        scope.find<MockStore>(),
        sessionId: sessionId,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SessionDetailController controller) {
    return LWatch(() {
      controller.storeTick.value;
      final embedded = PrototypeBreakpoints.detailDrawerActive(context);
      final store = controller.store;
      final session = store.sessionById(controller.sessionId);
      if (session == null) {
        return PrototypeDetailScaffold(
          embedded: embedded,
          fallbackRoute: '/calendar',
          title: 'Séance',
          body: const EmptyState(title: 'Séance introuvable'),
        );
      }

      final logbook = store.logbookForSession(controller.sessionId);
      final assessment = store.assessmentForSession(controller.sessionId);
      final activity = store.activityForSession(controller.sessionId);
      final textTheme = Theme.of(context).textTheme;

      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/calendar',
        titleWidget: Row(
          children: [
            SessionCategoryIcon(category: session.category, size: 18, padding: 6),
            const SizedBox(width: PrototypeSpacing.xs),
            Expanded(
              child: Text(
                session.subject,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(
                        label: session.category.label,
                        tone: _categoryTone(session.category),
                      ),
                      const Spacer(),
                      StatusChip(
                        label: session.attendance,
                        tone: _attendanceTone(session.attendance),
                      ),
                    ],
                  ),
                  const SizedBox(height: PrototypeSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enseignant', style: textTheme.labelSmall),
                            Text(session.teacher),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Horaire', style: textTheme.labelSmall),
                          Text(formatTimeRange(session.startHour, session.endHour)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.md),
            switch (session.category) {
              HomeDayCategory.lesson => _LessonDetailSection(logbook: logbook),
              HomeDayCategory.assessment => _AssessmentDetailSection(
                assessment: assessment,
              ),
              HomeDayCategory.activity => _ActivityDetailSection(activity: activity),
            },
          ],
        ),
      );
    });
  }
}

class _LessonDetailSection extends StatelessWidget {
  const _LessonDetailSection({required this.logbook});

  final MockLogbookEntry? logbook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Cahier de textes'),
        SurfaceCard(
          child: logbook == null
              ? Text(
                  'Aucune entrée de cahier de textes pour cette séance.',
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
                    if (logbook!.homework != null) ...[
                      const SizedBox(height: PrototypeSpacing.xs),
                      Text(
                        'Devoirs : ${logbook!.homework}',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: PrototypeSpacing.xs),
                    Text(
                      'Progression : ${logbook!.progress} %',
                      style: textTheme.bodySmall?.copyWith(
                        color: PrototypeColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AssessmentDetailSection extends StatelessWidget {
  const _AssessmentDetailSection({required this.assessment});

  final MockAssessmentDetail? assessment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (assessment == null) {
      return SurfaceCard(
        child: Text(
          'Aucun détail disponible pour cette évaluation.',
          style: textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Évaluation'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assessment!.title,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (assessment!.period != null) ...[
                const SizedBox(height: PrototypeSpacing.xs),
                Text(
                  assessment!.period!,
                  style: textTheme.bodySmall?.copyWith(
                    color: PrototypeColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: PrototypeSpacing.sm),
              Text(assessment!.description, style: textTheme.bodyMedium),
              const SizedBox(height: PrototypeSpacing.sm),
              Text('Consignes', style: textTheme.labelSmall),
              const SizedBox(height: PrototypeSpacing.xxs),
              Text(assessment!.instructions, style: textTheme.bodyMedium),
              if (assessment!.coefficient != null) ...[
                const SizedBox(height: PrototypeSpacing.sm),
                Text(
                  'Coefficient : ${assessment!.coefficient!.toStringAsFixed(0)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: PrototypeColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (assessment!.hasMark) ...[
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Note de l\'élève'),
          SurfaceCard(
            child: Row(
              children: [
                Text(
                  '${assessment!.score!.toStringAsFixed(0)}/${assessment!.maxScore!.toStringAsFixed(0)}',
                  style: textTheme.headlineSmall?.copyWith(
                    color: PrototypeColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                StatusChip(label: 'Publiée', tone: SemanticTone.success),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: PrototypeSpacing.md),
          SurfaceCard(
            child: Text(
              'La note n\'est pas encore publiée pour cette évaluation.',
              style: textTheme.bodyMedium?.copyWith(
                color: PrototypeColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityDetailSection extends StatelessWidget {
  const _ActivityDetailSection({required this.activity});

  final MockActivityDetail? activity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (activity == null) {
      return SurfaceCard(
        child: Text(
          'Aucun commentaire partagé pour cette activité.',
          style: textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Commentaire de l\'équipe'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity!.staffName,
                style: textTheme.labelLarge,
              ),
              const SizedBox(height: PrototypeSpacing.xxs),
              Text(
                formatDateTime(activity!.sharedAt),
                style: textTheme.bodySmall?.copyWith(
                  color: PrototypeColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: PrototypeSpacing.sm),
              Text(activity!.staffComment, style: textTheme.bodyMedium),
            ],
          ),
        ),
        if (activity!.photos.isNotEmpty) ...[
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Photos partagées'),
          for (final photo in activity!.photos) ...[
            _ActivityPhotoCard(photo: photo),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
        ],
      ],
    );
  }
}

class _ActivityPhotoCard extends StatelessWidget {
  const _ActivityPhotoCard({required this.photo});

  final MockActivityPhoto photo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrototypeRadii.md),
            ),
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: Image.network(
                photo.url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: PrototypeColors.primaryContainer,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(PrototypeSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(
                        label: photo.isGroup ? 'Groupe' : 'Individuelle',
                        tone: photo.isGroup ? SemanticTone.info : SemanticTone.neutral,
                      ),
                      const SizedBox(height: PrototypeSpacing.xs),
                      Text(photo.caption, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Partager',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Partage de « ${photo.caption} »')),
                    );
                  },
                  icon: const Icon(Icons.ios_share_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

SemanticTone _categoryTone(HomeDayCategory category) {
  return switch (category) {
    HomeDayCategory.lesson => SemanticTone.info,
    HomeDayCategory.activity => SemanticTone.neutral,
    HomeDayCategory.assessment => SemanticTone.warning,
  };
}

SemanticTone _attendanceTone(String status) {
  return switch (status) {
    'Absent' => SemanticTone.error,
    'Retard' => SemanticTone.warning,
    _ => SemanticTone.success,
  };
}
