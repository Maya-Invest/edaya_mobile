import 'package:flutter/material.dart';

import '../colors.dart';
import '../typography.dart';

class PrototypeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrototypeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: PrototypeColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text('edaya', style: PrototypeTypography.brandWordmark(size: 28)),
      centerTitle: true,
    );
  }
}
