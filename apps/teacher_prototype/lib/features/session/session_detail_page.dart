import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';

class SessionDetailPage extends LScopedView<StoreBoundController> {
  const SessionDetailPage({super.key, required this.sessionId});

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
      return const PrototypeDetailScaffold(
        title: 'Séance',
        body: EmptyState(title: 'Séance introuvable'),
      );
    }

    return PrototypeDetailScaffold(
      title: session.classLabel,
      fallbackRoute: '/calendar',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.subject, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: PrototypeSpacing.xs),
                Text(
                  '${formatFullDate(session.date)} · ${formatTimeRange(session.startHour, session.endHour)}',
                ),
                Text(session.room),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          ListRow(
            title: 'Présences',
            subtitle: session.attendanceComplete ? 'Complété' : 'À saisir',
            leading: const Icon(Icons.how_to_reg_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/session/$sessionId/attendance'),
          ),
          const SizedBox(height: PrototypeSpacing.xs),
          ListRow(
            title: 'Cahier de texte',
            subtitle: session.logbookComplete ? 'Complété' : 'À saisir',
            leading: const Icon(Icons.menu_book_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/session/$sessionId/logbook'),
          ),
        ],
      ),
    );
  }
}
