import 'package:flutter/material.dart';

import '../colors.dart';
import '../typography.dart';

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
          package: 'edaya_shared',
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

