import '../../design/workspace_layout.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import 'attendance_page.dart';
import 'live_session_controller.dart';

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
                Text(
                  session.subject,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
            onTap: () => openLessonEntry(context, sessionId, 'attendance'),
          ),
          const SizedBox(height: PrototypeSpacing.xs),
          ListRow(
            title: context.tr.logbook,
            subtitle: session.logbookComplete ? 'Complété' : 'À saisir',
            leading: const Icon(Icons.menu_book_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openLessonEntry(context, sessionId, 'logbook'),
          ),
        ],
      ),
    );
  }
}

class _LiveSessionDetailPage extends LScopedView<LiveSessionController> {
  const _LiveSessionDetailPage({required this.sessionId});

  final String sessionId;

  @override
  LiveSessionController onConfigScope(LevitScope scope) {
    return putLiveSessionController(scope, sessionId);
  }

  @override
  Widget buildView(BuildContext context, LiveSessionController controller) {
    return LWatch(() {
      controller.session.value;
      controller.students.value;
      controller.content.value;
      controller.errorMessage.value;
      final session = controller.session.value;
      if (session == null) {
        return PrototypeDetailScaffold(
          title: 'Séance',
          body: EmptyState(
            title: 'Séance introuvable',
            message: controller.errorMessage.value,
          ),
        );
      }

      return PrototypeDetailScaffold(
        title: session.classLabel,
        fallbackRoute: '/calendar',
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            WorkspaceColumns(
              first: [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.subjectLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: PrototypeSpacing.xs),
                      Text(
                        '${formatFullDate(session.startsAt)} · ${formatClockRange(session.startsAt, session.endsAt)}',
                      ),
                    ],
                  ),
                ),
              ],
              second: [
                ListRow(
                  title: 'Présences',
                  subtitle: session.kind != 'lesson'
                      ? 'Non disponible'
                      : (controller.attendanceComplete
                            ? 'Complété'
                            : 'À saisir'),
                  leading: const Icon(Icons.how_to_reg_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: session.kind == 'lesson'
                      ? () => openLessonEntry(context, sessionId, 'attendance')
                      : null,
                ),
                const SizedBox(height: PrototypeSpacing.xs),
                ListRow(
                  title: context.tr.logbook,
                  subtitle: session.kind != 'lesson'
                      ? 'Non disponible'
                      : (controller.logbookComplete ? 'Complété' : 'À saisir'),
                  leading: const Icon(Icons.menu_book_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: session.kind == 'lesson'
                      ? () => openLessonEntry(context, sessionId, 'logbook')
                      : null,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

void openLessonEntry(BuildContext context, String sessionId, String entry) {
  if (GoRouterState.of(context).uri.path.startsWith('/calendar/lesson/')) {
    Router.neglect(
      context,
      () => context.replace('/calendar/lesson/$sessionId/$entry'),
    );
  } else {
    context.push('/session/$sessionId/$entry');
  }
}
