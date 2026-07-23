import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Centers [child] and caps width on medium+ screens.
///
/// Pass [constrain] false when already inside a master–detail pane.
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({
    super.key,
    required this.child,
    this.constrain = true,
    this.maxWidth = PrototypeBreakpoints.maxContentWidth,
  });

  final Widget child;
  final bool constrain;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!constrain) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
