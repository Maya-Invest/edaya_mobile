import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/guardian_words.dart';
import '../../design/components/surface_card.dart';
import 'period_results_controller.dart';
import 'period_results_scope.dart';
import 'report_card_controller.dart';

String resultLabel(Map<String, dynamic> row) => formatCalculatedGrade(
  (row['average'] as num?)?.toDouble(),
  (row['grading'] as Map?)?.cast<String, dynamic>(),
);
List<Map<String, dynamic>> sectionChildren(Map<String, dynamic> row) =>
    (row['subResults'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

class ResultsPage extends LScopedView<PeriodResultsController> {
  const ResultsPage({super.key, this.period});
  final String? period;
  @override
  PeriodResultsController onConfigScope(LevitScope scope) =>
      scope.put(() => periodResultsFor(scope, period));
  @override
  Widget buildView(BuildContext context, PeriodResultsController controller) {
    final data = controller.result.value;
    final selected = controller.selectedPeriod.value;
    return ListView(
      key: const PageStorageKey('results'),
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: words(context, 'Période', 'Period'),
          ),
          items: [
            for (final p in controller.periods.value)
              DropdownMenuItem(
                value: p['id'] as String,
                child: Text('${p['name'] ?? p['label'] ?? p['id']}'),
              ),
          ],
          onChanged: (id) {
            if (id != null) controller.select(id);
          },
        ),
        const SizedBox(height: 20),
        if (controller.loading.value) const LinearProgressIndicator(),
        if (controller.failed.value)
          _Retry(
            onTap: () => selected == null
                ? controller.initialize()
                : controller.select(selected),
          ),
        if (!controller.loading.value && controller.periods.value.isEmpty)
          Text(
            words(
              context,
              'Aucune période disponible.',
              'No periods available.',
            ),
          ),
        if (data != null) ...[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['state'] == 'published'
                      ? words(context, 'Bulletin publié', 'Published report')
                      : words(
                          context,
                          'Résultats provisoires',
                          'Provisional results',
                        ),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  resultLabel(data),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (data['calculationReady'] != true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      words(
                        context,
                        'Les moyennes sont en cours de calcul. Les notes restent consultables.',
                        'Averages are being calculated. Marks remain available.',
                      ),
                    ),
                  ),
                for (final key in ['teacherComment', 'principalComment'])
                  if (data[key] is String && (data[key] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(data[key] as String),
                    ),
                if (data['reportId'] is String)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _ReportDownload(
                      key: ValueKey(data['reportId']),
                      reportId: data['reportId'] as String,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (controller.sections.isEmpty)
            Text(
              words(
                context,
                'Aucun résultat disponible pour cette période.',
                'No results available for this period.',
              ),
            ),
          for (final section in controller.sections) ...[
            if (section['sectionKind'] == 'module')
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  key: PageStorageKey((
                    controller.studentId,
                    selected,
                    section['sectionId'],
                  )),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  maintainState: true,
                  title: Text(
                    '${section['name']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(resultLabel(section)),
                  children: [
                    if (section['comment'] is String)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(section['comment'] as String),
                      ),
                    for (final subject in sectionChildren(section))
                      _SubjectRow(
                        subject: subject,
                        period: selected!,
                        year: controller.yearId,
                      ),
                  ],
                ),
              )
            else
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: _SubjectRow(
                  subject: section,
                  period: selected!,
                  year: controller.yearId,
                ),
              ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.period,
    required this.year,
  });
  final Map<String, dynamic> subject;
  final String period, year;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    title: Text('${subject['name']}'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
              resultLabel(subject),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(
              '${words(context, 'Coefficient', 'Coefficient')} ${subject['coefficient'] ?? '—'}',
            ),
          ],
        ),
        if (subject['comment'] is String) Text(subject['comment'] as String),
      ],
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(
      Uri(
        path:
            '/scolarite/period/$period/subject/${subject['subjectId'] ?? subject['classSubjectId']}',
        queryParameters: {'year': year},
      ).toString(),
    ),
  );
}

class _ReportDownload extends LScopedView<ReportCardController> {
  const _ReportDownload({super.key, required this.reportId});
  final String reportId;
  @override
  ReportCardController onConfigScope(LevitScope scope) => scope.put(
    () => ReportCardController(
      reportCardId: reportId,
      schoolClient: scope.find<SchoolClientFactory>(),
    ),
  );
  @override
  Widget buildView(BuildContext context, ReportCardController controller) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed:
                controller.downloadStatus.value ==
                    ReportCardPdfStatus.downloading
                ? null
                : controller.downloadPdf,
            icon: const Icon(Icons.download_outlined),
            label: Text(
              words(context, 'Télécharger le bulletin', 'Download report card'),
            ),
          ),
          if (controller.downloadMessage.value.isNotEmpty)
            Text(controller.downloadMessage.value),
        ],
      );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          words(
            context,
            'Impossible de charger les résultats.',
            'Unable to load results.',
          ),
        ),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.refresh),
          label: Text(words(context, 'Réessayer', 'Retry')),
        ),
      ],
    ),
  );
}
