import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';
import 'surface_card.dart';

class AttentionCard extends StatelessWidget {
  const AttentionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onAction,
    this.icon = Icons.notifications_active_outlined,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PrototypeSpacing.md),
      decoration: PrototypeElevation.cardDecoration(
        background: PrototypeColors.primaryContainer,
        radius: PrototypeRadii.lg,
        shadow: const [
          BoxShadow(
            color: Color(0x1A2563EB),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PrototypeColors.primary),
              const SizedBox(width: PrototypeSpacing.xs),
              Text(
                'Action requise',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: PrototypeColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrototypeSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: PrototypeSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryMetric extends StatelessWidget {
  const SummaryMetric({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PrototypeSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.initials,
    this.radius = 20,
    this.photoUrl,
  });

  final String initials;
  final double radius;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsAvatar(),
        ),
      );
    }

    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: PrototypeColors.primary,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: PrototypeTypography.uiFamily,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

class PrototypeDetailScaffold extends StatelessWidget {
  const PrototypeDetailScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.fallbackRoute = '/home',
  });

  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final String fallbackRoute;

  static void popOrGo(BuildContext context, {required String fallbackRoute}) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrototypeColors.background,
      appBar: AppBar(
        backgroundColor: PrototypeColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () => popOrGo(context, fallbackRoute: fallbackRoute),
        ),
        title: titleWidget ?? (title != null ? Text(title!) : null),
      ),
      body: body,
    );
  }
}

class PrototypeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrototypeAppBar({
    super.key,
    this.onProfileTap,
    this.onHelpTap,
  });

  final VoidCallback? onProfileTap;
  final VoidCallback? onHelpTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: PrototypeColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Mon compte',
        icon: const Icon(Icons.account_circle_outlined),
        onPressed: onProfileTap,
      ),
      title: Text('edaya', style: PrototypeTypography.brandWordmark(size: 28)),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Aide',
          icon: const Icon(Icons.help_outline),
          onPressed: onHelpTap,
        ),
      ],
    );
  }
}

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
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.expand_more, size: 22),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onPressed: onSelectStudent,
            ),
          ],
        ),
      ),
    );
  }
}

class AcademicYearPicker extends StatelessWidget {
  const AcademicYearPicker({
    super.key,
    required this.selectedYear,
    required this.years,
    required this.onSelected,
  });

  final String selectedYear;
  final List<String> years;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        maximumSize: WidgetStateProperty.all(const Size(280, 320)),
      ),
      builder: (context, controller, child) {
        return TextButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.expand_more, size: 18),
          label: Text(selectedYear),
        );
      },
      menuChildren: [
        for (final year in years)
          MenuItemButton(
            onPressed: () => onSelected(year),
            trailingIcon: year == selectedYear
                ? Icon(Icons.check, size: 18, color: PrototypeColors.primary)
                : null,
            child: Text(year),
          ),
      ],
    );
  }
}

/// @deprecated Use [PrototypeAppBar] and [StudentContextCard] instead.
class ShellContextBar extends StatelessWidget {
  const ShellContextBar({
    super.key,
    required this.studentName,
    required this.studentInitials,
    required this.classLabel,
    required this.schoolYear,
    required this.guardianName,
    required this.guardianInitials,
    this.onStudentTap,
    this.onGuardianTap,
  });

  final String studentName;
  final String studentInitials;
  final String classLabel;
  final String schoolYear;
  final String guardianName;
  final String guardianInitials;
  final VoidCallback? onStudentTap;
  final VoidCallback? onGuardianTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrototypeSpacing.md,
        PrototypeSpacing.sm,
        PrototypeSpacing.md,
        PrototypeSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StudentSelectorChip(
              name: studentName,
              initials: studentInitials,
              classLabel: classLabel,
              schoolYear: schoolYear,
              onTap: onStudentTap,
            ),
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          _GuardianProfileChip(
            name: guardianName,
            initials: guardianInitials,
            onTap: onGuardianTap,
          ),
        ],
      ),
    );
  }
}

class _StudentSelectorChip extends StatelessWidget {
  const _StudentSelectorChip({
    required this.name,
    required this.initials,
    required this.classLabel,
    required this.schoolYear,
    this.onTap,
  });

  final String name;
  final String initials;
  final String classLabel;
  final String schoolYear;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrototypeRadii.md),
        child: DecoratedBox(
          decoration: PrototypeElevation.cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PrototypeSpacing.sm,
              PrototypeSpacing.xs,
              PrototypeSpacing.sm,
              PrototypeSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  schoolYear,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: PrototypeColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    PersonAvatar(initials: initials, radius: 18),
                    const SizedBox(width: PrototypeSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            classLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.expand_more,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuardianProfileChip extends StatelessWidget {
  const _GuardianProfileChip({
    required this.name,
    required this.initials,
    this.onTap,
  });

  final String name;
  final String initials;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrototypeRadii.md),
        child: DecoratedBox(
          decoration: PrototypeElevation.cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PrototypeSpacing.sm,
              vertical: PrototypeSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PersonAvatar(initials: initials, radius: 16),
                const SizedBox(width: PrototypeSpacing.xs),
                Text(
                  name.split(' ').first,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// @deprecated Use [ShellContextBar] instead.
class ContextHeader extends StatelessWidget {
  const ContextHeader({
    super.key,
    required this.studentName,
    required this.classLabel,
    required this.yearLabel,
    this.onStudentTap,
    this.onYearTap,
  });

  final String studentName;
  final String classLabel;
  final String yearLabel;
  final VoidCallback? onStudentTap;
  final VoidCallback? onYearTap;

  @override
  Widget build(BuildContext context) {
    return ShellContextBar(
      studentName: studentName,
      studentInitials: studentName.isNotEmpty ? studentName[0] : '?',
      classLabel: classLabel,
      schoolYear: yearLabel,
      guardianName: 'Parent',
      guardianInitials: 'P',
      onStudentTap: onStudentTap,
      onGuardianTap: onYearTap,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PrototypeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: PrototypeSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: PrototypeSpacing.xs),
              Text(message!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: PrototypeSpacing.md),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class PrototypeProgressBar extends StatelessWidget {
  const PrototypeProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PrototypeRadii.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 8,
        backgroundColor: PrototypeColors.primaryContainer,
        color: PrototypeColors.primary,
      ),
    );
  }
}
