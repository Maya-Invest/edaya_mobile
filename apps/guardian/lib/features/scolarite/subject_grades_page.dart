import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/guardian_words.dart';
import '../../design/components/surface_card.dart';
import 'period_results_controller.dart';
import 'period_results_scope.dart';
import 'results_page.dart';

class SubjectGradesPage extends LScopedView<PeriodResultsController> {
  const SubjectGradesPage({
    super.key,
    required this.periodId,
    required this.subject,
    this.expandedMark,
  });
  final String periodId, subject;
  final String? expandedMark;
  @override
  PeriodResultsController onConfigScope(LevitScope scope) => scope.put(
    () => periodResultsFor(
      scope,
      periodId,
      subjectId: subject,
      focusMarkId: expandedMark,
    ),
  );
  @override
  Widget buildView(BuildContext context, PeriodResultsController controller) {
    if (controller.loading.value) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.failed.value) {
      return Center(
        child: TextButton.icon(
          onPressed: () => controller.select(periodId),
          icon: const Icon(Icons.refresh),
          label: Text(words(context, 'Réessayer', 'Retry')),
        ),
      );
    }
    final subjects = [
      for (final row in controller.sections)
        if (row['sectionKind'] == 'subject') row else ...sectionChildren(row),
    ];
    final section = subjects
        .where(
          (s) => s['subjectId'] == subject || s['classSubjectId'] == subject,
        )
        .firstOrNull;
    if (section == null) {
      return Center(
        child: Text(
          words(context, 'Matière indisponible.', 'Subject unavailable.'),
        ),
      );
    }
    final marks = controller.marks
        .where(
          (m) =>
              m['subjectId'] == section['subjectId'] ||
              m['classSubjectId'] == section['classSubjectId'],
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${section['name']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${controller.result.value?['periodName'] ?? controller.periods.value.where((p) => p['id'] == periodId).firstOrNull?['name'] ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              GradeValue(
                resultLabel(section),
                section,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                controller.result.value?['state'] == 'published'
                    ? words(
                        context,
                        'Résultat du bulletin publié',
                        'Published report result',
                      )
                    : words(
                        context,
                        'Moyenne provisoire',
                        'Provisional average',
                      ),
              ),
              if (section['coefficient'] is num)
                Text(
                  context.tr.coefficient(
                    formatGradeNumber(section['coefficient'] as num),
                  ),
                ),
              if (section['comment'] is String)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(section['comment'] as String),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          words(context, 'Toutes les notes', 'All marks'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (marks.isEmpty)
          Text(
            words(context, 'Aucune note disponible.', 'No marks available.'),
          ),
        for (final mark in marks) ...[
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: GradeRecordRow(
              key: PageStorageKey(mark['id']),
              initiallyExpanded: mark['id'] == expandedMark,
              title: '${mark['title']}',
              result: mark,
              details: Column(
                spacing: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mark['date'] case final String date)
                    Text(
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).languageCode,
                      ).format(DateTime.parse(date)),
                    ),
                  if (mark['coefficient'] is num)
                    Text(
                      context.tr.coefficient(
                        formatGradeNumber(mark['coefficient'] as num),
                      ),
                    ),
                  if (mark['notes'] is String &&
                      (mark['notes'] as String).trim().isNotEmpty)
                    Text(mark['notes'] as String),
                  for (final field in ['description', 'instructions'])
                    if (mark[field] is String &&
                        (mark[field] as String).trim().isNotEmpty)
                      Text(mark[field] as String),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (controller.result.value?['nextCursor'] != null)
          TextButton(
            onPressed: controller.loadingMore.value
                ? null
                : controller.loadMore,
            child: Text(
              controller.pageFailed.value
                  ? words(context, 'Réessayer', 'Retry')
                  : words(context, 'Afficher plus de notes', 'Load more marks'),
            ),
          ),
      ],
    );
  }
}

String markLabel(BuildContext context, Map<String, dynamic> mark) =>
    officialMarkLabel(context, mark);
