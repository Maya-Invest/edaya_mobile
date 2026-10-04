import 'package:flutter/material.dart';

import '../../app/formatters.dart';
import '../../mock/mock_store.dart';
import '../colors.dart';
import '../spacing.dart';
import 'status_chip.dart';
import 'surface_card.dart';
import 'list_row.dart';

class NoSchoolDayBanner extends StatelessWidget {
  const NoSchoolDayBanner({super.key, required this.event});

  final MockEvent event;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      tint: PrototypeColors.errorContainer.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_busy_outlined, color: PrototypeColors.error),
          const SizedBox(width: PrototypeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pas d\'école',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: PrototypeColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          StatusChip(label: event.kind, tone: SemanticTone.error),
        ],
      ),
    );
  }
}

class SchoolEventRow extends StatelessWidget {
  const SchoolEventRow({super.key, required this.event});

  final MockEvent event;

  @override
  Widget build(BuildContext context) {
    if (event.isNonSchoolDay) {
      return SurfaceCard(
        tint: PrototypeColors.errorContainer.withValues(alpha: 0.25),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.event_busy_outlined,
              color: PrototypeColors.error,
              size: 20,
            ),
            const SizedBox(width: PrototypeSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      event.kind,
                      event.description,
                    ].where((part) => part.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            StatusChip(label: 'Sans école', tone: SemanticTone.error),
          ],
        ),
      );
    }

    return ListRow(
      title: event.title,
      subtitle: [event.kind, formatDate(event.date)].join(' · '),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: PrototypeColors.accentContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.event, size: 20, color: Colors.orange),
      ),
    );
  }
}
