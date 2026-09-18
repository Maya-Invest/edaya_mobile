import 'package:flutter/material.dart';

import '../colors.dart';
import '../typography.dart';

class PrototypeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrototypeAppBar({super.key, this.onProfileTap, this.onHelpTap});

  /// When null, the profile control is omitted (e.g. tablet rail owns it).
  final VoidCallback? onProfileTap;

  /// When null, the help control is omitted (e.g. tablet rail owns it).
  final VoidCallback? onHelpTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final showProfile = onProfileTap != null;
    final showHelp = onHelpTap != null;

    return AppBar(
      backgroundColor: PrototypeColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showProfile
          ? IconButton(
              tooltip: 'Mon compte',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: onProfileTap,
            )
          : null,
      title: Text('edaya', style: PrototypeTypography.brandWordmark(size: 28)),
      centerTitle: true,
      actions: [
        if (showHelp)
          IconButton(
            tooltip: 'Aide',
            icon: const Icon(Icons.help_outline),
            onPressed: onHelpTap,
          ),
      ],
    );
  }
}
