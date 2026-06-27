import 'package:flutter/material.dart';

import '../models/curriculum_subject.dart';

class CurriculumProgressTile extends StatelessWidget {
  const CurriculumProgressTile({super.key, required this.subject});

  final CurriculumSubject subject;

  @override
  Widget build(BuildContext context) {
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
            Text('${subject.completedPercentage}% complete'),
          ],
        ),
        children: subject.units.isEmpty
            ? const [
                ListTile(
                  title: Text('No programme units tracked yet.'),
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
