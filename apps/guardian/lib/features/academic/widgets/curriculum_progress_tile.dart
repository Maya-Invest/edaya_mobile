import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../models/curriculum_subject.dart';

class CurriculumProgressTile extends StatelessWidget {
  const CurriculumProgressTile({super.key, required this.subject});

  final CurriculumSubject subject;

  @override
  Widget build(BuildContext context) {
    final l10n = context.tr;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(subject.subjectName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: subject.completedPercentage / 100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 4),
            Text(l10n.percentComplete(subject.completedPercentage)),
          ],
        ),
        children: subject.units.isEmpty
            ? [
                ListTile(
                  title: Text(l10n.noProgrammeUnitsTracked),
                ),
              ]
            : [
                for (final unit in subject.units)
                  ListTile(
                    title: Text(unit.name),
                    subtitle: LinearProgressIndicator(
                      value: unit.completedPercentage / 100,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    trailing: Text('${unit.completedPercentage}%'),
                  ),
              ],
      ),
    );
  }
}
