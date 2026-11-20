import 'package:flutter/material.dart';

/// Wraps existing metrics without shrinking amounts or enlarged text.
class ResponsiveMetrics extends StatelessWidget {
  const ResponsiveMetrics({
    super.key,
    required this.children,
    this.minimumWidth = 150,
  });
  final List<Widget> children;
  final double minimumWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = (constraints.maxWidth / (minimumWidth * scale))
          .floor()
          .clamp(1, children.length);
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
