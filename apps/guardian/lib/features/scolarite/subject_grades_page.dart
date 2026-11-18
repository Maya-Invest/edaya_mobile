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
  PeriodResultsController onConfigScope(LevitScope scope) =>
      scope.put(() => periodResultsFor(scope, periodId));
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
                '${controller.periods.value.where((p) => p['id'] == periodId).firstOrNull?['name'] ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                resultLabel(section),
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
            child: ExpansionTile(
              key: PageStorageKey(mark['id']),
              initiallyExpanded: mark['id'] == expandedMark,
              maintainState: true,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text('${mark['title']}'),
              subtitle: Text(
                [
                  if (mark['date'] is String)
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).languageCode,
                    ).format(DateTime.parse(mark['date'] as String)),
                  markLabel(context, mark),
                ].join(' · '),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${words(context, 'Coefficient', 'Coefficient')} : ${formatGradeNumber(mark['coefficient'] as num?)}',
                        ),
                      ),
                      if (mark['notes'] is String &&
                          (mark['notes'] as String).trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(mark['notes'] as String),
                      ],
                      for (final field in ['description', 'instructions'])
                        if (mark[field] is String &&
                            (mark[field] as String).trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(mark[field] as String),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

String markLabel(BuildContext context, Map<String, dynamic> mark) {
  if (mark['designation'] == 'absent') {
    return words(context, 'Absent', 'Absent');
  }
  if (mark['designation'] == 'exempt') {
    return words(context, 'Dispensé', 'Exempt');
  }
  final grading = (mark['grading'] as Map?)?.cast<String, dynamic>();
  if (grading != null) {
    return formatCalculatedGrade(
      (grading['reportedValue'] as num?)?.toDouble(),
      grading,
    );
  }
  final entry = mark['originalEntry'] as Map?;
  if (entry?['kind'] == 'mention') {
    return '${entry?['label'] ?? entry?['code'] ?? '—'}';
  }
  return mark['score'] == null
      ? '—'
      : '${formatGradeNumber(mark['score'] as num?)} / ${formatGradeNumber(mark['maxScore'] as num?)}';
}
