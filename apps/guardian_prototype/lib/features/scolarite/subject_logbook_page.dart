import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
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
        scope.find<MockStore>(),
        subject: subject,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SubjectLogbookController controller) {
        controller.storeTick.value;
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);
    final store = controller.store;
    final subject = controller.subject;
    final progress = store.progressForSubject(subject);
    final entries = store.logbookForSubject(subject);

    return PrototypeDetailScaffold(
      embedded: embedded,
      fallbackRoute: '/scolarite/notes',
      title: subject,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cahier de textes',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: PrototypeSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${(progress * 100).round()} % du programme couvert',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      store.statusForSubject(subject),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                PrototypeProgressBar(value: progress),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Entrées'),
          if (entries.isEmpty)
            const EmptyState(
              title: 'Aucune entrée pour cette matière',
              message: 'Le cahier de textes sera affiché ici au fur et à mesure.',
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
