import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'inbox_controller.dart';

class InboxPage extends LScopedView<InboxController> {
  const InboxPage({super.key});

  @override
  InboxController onConfigScope(LevitScope scope) {
    return scope.put(
      () => InboxController(
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, InboxController controller) {
    final selectedId = GoRouterState.of(context).pathParameters['id'];

    if (controller.dataStatus == DataStatus.loading) {
      return const AdaptiveContent(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.dataStatus == DataStatus.error) {
      return AdaptiveContent(
        child: EmptyState(title: controller.errorMessage.value),
      );
    }

    final deliveries = controller.deliveries.value;
    if (deliveries.isEmpty) {
      return AdaptiveContent(
        child: EmptyState(title: controller.emptyMessage),
      );
    }

    return AdaptiveContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '${controller.unreadCount} non lu(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(PrototypeSpacing.md),
              itemCount: deliveries.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PrototypeSpacing.xs),
              itemBuilder: (context, i) {
                final m = deliveries[i];
                final selected = selectedId == m.id;
                final sentAt = m.sortDate;
                return ListRow(
                  title: m.title,
                  subtitle: m.body.length > 80
                      ? '${m.body.substring(0, 80)}…'
                      : m.body,
                  unread: m.isUnread,
                  selected: selected,
                  badge: m.isUnread
                      ? 'Nouveau'
                      : sentAt == null
                      ? 'Lu'
                      : 'Lu · ${formatDate(sentAt)}',
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: m.isUnread
                          ? PrototypeColors.primaryContainer
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.mail_outline,
                      size: 20,
                      color: m.isUnread
                          ? PrototypeColors.primary
                          : PrototypeColors.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => context.go('/inbox/message/${m.id}'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: selected
                        ? PrototypeColors.primary
                        : PrototypeColors.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
