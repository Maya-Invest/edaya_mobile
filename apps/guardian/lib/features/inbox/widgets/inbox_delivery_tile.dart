import 'package:flutter/material.dart';

import '../../../common/utils/date_time_parse.dart';
import '../models/inbox_delivery.dart';

class InboxDeliveryTile extends StatelessWidget {
  const InboxDeliveryTile({
    super.key,
    required this.delivery,
    required this.onTap,
  });

  final InboxDelivery delivery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUnread = delivery.isUnread;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: isUnread
            ? Icon(Icons.mark_email_unread_outlined, color: colorScheme.primary)
            : Icon(Icons.mail_outline, color: colorScheme.onSurfaceVariant),
        title: Text(
          delivery.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isUnread ? theme.textTheme.titleSmall : theme.textTheme.bodyLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              delivery.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              [
                delivery.status.label,
                if (delivery.sortDate != null)
                  formatShortDate(delivery.sortDate!),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
