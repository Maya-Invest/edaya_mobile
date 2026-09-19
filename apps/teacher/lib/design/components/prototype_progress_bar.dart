import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';

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
