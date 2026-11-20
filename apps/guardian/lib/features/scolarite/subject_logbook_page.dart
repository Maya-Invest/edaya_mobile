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
  const SubjectLogbookPage({
    super.key,
    required this.subject,
    this.byId = false,
  });

  final String subject;
  final bool byId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveSubjectLogbookPage(
        key: ValueKey((subject, byId)),
        subject: subject,
        byId: byId,
      );
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
          Text(resolvedSubject, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PrototypeSpacing.sectionGap),
          SectionHeader(title: context.tr.entries),
          if (entries.isEmpty)
            EmptyState(
              title: context.tr.noLogbookEntriesForThisSubject,
              message: context.tr.logbookEntriesWillAppearHereAsTheyAre,
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
  const _LiveSubjectLogbookPage({
    super.key,
    required this.subject,
    required this.byId,
  });

  final String subject;
  final bool byId;

  @override
  SubjectLogbookController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SubjectLogbookController(
        subject: subject,
        byId: byId,
        studentContext: scope.find<StudentContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SubjectLogbookController controller) {
    final entries = controller.entries.value;
    final title =
        controller.subjectLabel.value ?? (byId ? context.tr.logbook : subject);

    if (controller.isBusy.value && entries.isEmpty) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: title,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PrototypeDetailScaffold(
      fallbackRoute: '/scolarite/notes',
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PrototypeSpacing.sectionGap),
          SectionHeader(title: context.tr.entries),
          if (entries.isEmpty)
            EmptyState(
              title: context.tr.noLogbookEntriesForThisSubject,
              message: context.tr.logbookEntriesWillAppearHereAsTheyAre,
            )
          else
            for (final entry in entries) ...[
              ListRow(
                title: entry.displayLabel,
                subtitle: [
                  formatDate(entry.startsAt),
                  decodeStructuredSessionNote(entry.sessionNote).guardianText,
                  ...entry.matterSnapshots.map(
                    (m) =>
                        '${m.matterName} · ${m.completed == null
                            ? context.tr.logbookReference
                            : m.completed!
                            ? context.tr.logbookFinishedHere
                            : context.tr.logbookCovered}${m.notes == null ? '' : ' · ${m.notes}'}',
                  ),
                ].where((part) => part.isNotEmpty).join('\n'),
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
        ],
      ),
    );
  }
}
