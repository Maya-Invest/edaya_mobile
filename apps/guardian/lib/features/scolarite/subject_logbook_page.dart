import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'subject_logbook_controller.dart';

class SubjectLogbookPage extends StatelessWidget {
  const SubjectLogbookPage({super.key, required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveSubjectLogbookPage(subject: subject);
    }
    return _MockSubjectLogbookPage(subject: subject);
  }
}

class _MockSubjectLogbookPage extends LScopedView<StoreBoundController> {
  const _MockSubjectLogbookPage({required this.subject});

  final String subject;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final resolvedSubject = MockStore.subjectFromRouteParam(subject);
    final entries = controller.store.logbookForSubject(resolvedSubject);
    return PrototypeDetailScaffold(
      fallbackRoute: '/scolarite/notes',
      title: resolvedSubject,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          const SectionHeader(title: 'Entrées'),
          if (entries.isEmpty)
            const EmptyState(
              title: 'Aucune entrée pour cette matière',
              message:
                  'Le cahier de textes sera affiché ici au fur et à mesure.',
            )
          else
            for (final entry in entries) ...[
              ListRow(
                title: entry.chapter,
                subtitle: '${formatDate(entry.date)} · ${entry.content}',
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
        ],
      ),
    );
  }
}

class _LiveSubjectLogbookPage extends LScopedView<SubjectLogbookController> {
  const _LiveSubjectLogbookPage({required this.subject});

  final String subject;

  @override
  SubjectLogbookController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SubjectLogbookController(
        subject: subject,
        studentContext: scope.find<StudentContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SubjectLogbookController controller) {
    final entries = controller.entries.value;

    if (controller.isBusy.value && entries.isEmpty) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: subject,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PrototypeDetailScaffold(
      fallbackRoute: '/scolarite/notes',
      title: subject,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          const SectionHeader(title: 'Entrées'),
          if (entries.isEmpty)
            const EmptyState(
              title: 'Aucune entrée pour cette matière',
              message:
                  'Le cahier de textes sera affiché ici au fur et à mesure.',
            )
          else
            for (final entry in entries) ...[
              ListRow(
                title: entry.displayLabel,
                subtitle:
                    '${formatDate(entry.startsAt)} · ${decodeStructuredSessionNote(entry.sessionNote).guardianText.isNotEmpty ? decodeStructuredSessionNote(entry.sessionNote).guardianText : entry.matterSnapshots.map((m) => m.matterName).join(', ')}',
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
        ],
      ),
    );
  }
}
