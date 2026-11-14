import 'package:edaya_shared/edaya_shared.dart' as shared;
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
    return shared.PersonAvatar(
      name: initials,
      initials: initials,
      photoUrl: photoUrl,
      radius: radius,
      backgroundColor: PrototypeColors.primary,
      initialsStyle: TextStyle(
        fontFamily: PrototypeTypography.uiFamily,
        package: 'edaya_shared',
        fontWeight: FontWeight.w600,
        color: Colors.white,
        fontSize: radius * 0.7,
      ),
    );
  }
}
