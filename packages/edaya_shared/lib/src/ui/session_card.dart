import 'package:flutter/material.dart';

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.leading,
    this.statusBadge,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;
  final Widget? statusBadge;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: leading,
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (statusBadge != null) ...[
              const SizedBox(height: 8),
              statusBadge!,
            ],
          ],
        ),
        isThreeLine: statusBadge != null,
        trailing: trailing ?? const Icon(Icons.chevron_right),
      ),
    );
  }
}
