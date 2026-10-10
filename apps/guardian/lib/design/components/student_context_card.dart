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
    this.onOpenProfile,
    this.onSelectStudent,
  });

  final String studentName;
  final String studentInitials;
  final String classLabel;
  final String schoolName;
  final String schoolYear;
  final String? photoUrl;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onSelectStudent;

  @override
  Widget build(BuildContext context) {
    final classYear = '$classLabel · $schoolYear';
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        PrototypeSpacing.sm,
        PrototypeSpacing.sm,
        PrototypeSpacing.xs,
        PrototypeSpacing.sm,
      ),
      child: MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: onOpenProfile,
                      child: PersonAvatar(
                        initials: studentInitials,
                        photoUrl: photoUrl,
                        radius: PrototypeSpacing.xl,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Choisir un élève',
                      icon: const Icon(Icons.expand_more),
                      onPressed: onSelectStudent,
                    ),
                  ],
                ),
                InkWell(
                  onTap: onOpenProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName, style: textTheme.titleSmall),
                      Text(
                        schoolName,
                        style: textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(classYear, style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                InkWell(
                  onTap: onOpenProfile,
                  borderRadius: BorderRadius.circular(24),
                  child: PersonAvatar(
                    initials: studentInitials,
                    photoUrl: photoUrl,
                    radius: PrototypeSpacing.xl,
                  ),
                ),
                const SizedBox(width: PrototypeSpacing.sm),
                Expanded(
                  child: InkWell(
                    onTap: onOpenProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          studentName,
                          style: textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          schoolName,
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          classYear,
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
    );
  }
}
