import 'package:flutter/material.dart';

import '../spacing.dart';
import 'person_avatar.dart';
import 'surface_card.dart';

class StudentContextCard extends StatelessWidget {
  const StudentContextCard({
    super.key,
    required this.studentName,
    required this.studentInitials,
    required this.classLabel,
    required this.schoolName,
    required this.schoolYear,
    this.photoUrl,
    this.onSelectStudent,
  });

  final String studentName;
  final String studentInitials;
  final String classLabel;
  final String schoolName;
  final String schoolYear;
  final String? photoUrl;
  final VoidCallback? onSelectStudent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrototypeSpacing.md,
        0,
        PrototypeSpacing.md,
        PrototypeSpacing.sm,
      ),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(
          PrototypeSpacing.sm,
          PrototypeSpacing.sm,
          PrototypeSpacing.xs,
          PrototypeSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonAvatar(
              initials: studentInitials,
              photoUrl: photoUrl,
              radius: 24,
            ),
            const SizedBox(width: PrototypeSpacing.sm),
            Expanded(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          studentName,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: PrototypeSpacing.sm),
                      Expanded(
                        child: Text(
                          schoolName,
                          style: Theme.of(context).textTheme.titleSmall,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          classLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: PrototypeSpacing.sm),
                      Expanded(
                        child: Text(
                          schoolYear,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Choisir un élève',
              icon: const Icon(Icons.expand_more),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onPressed: onSelectStudent,
            ),
          ],
        ),
      ),
    );
  }
}
