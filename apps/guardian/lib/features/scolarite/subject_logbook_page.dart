import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../context/student_context_controller.dart';
import 'subject_logbook_controller.dart';

class SubjectLogbookPage extends LScopedView<SubjectLogbookController> {
  const SubjectLogbookPage({
    super.key,
    required this.subject,
  });

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
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);
    final entries = controller.entries.value;

    if (controller.isBusy.value && entries.isEmpty) {
      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/scolarite/notes',
        title: subject,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PrototypeDetailScaffold(
      embedded: embedded,
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
                    '${formatDate(entry.startsAt)} · ${entry.sessionNote ?? entry.matterSnapshots.map((m) => m.matterName).join(', ')}',
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
        ],
      ),
    );
  }
}
