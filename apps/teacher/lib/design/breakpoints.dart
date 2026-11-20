import 'package:flutter/widgets.dart';

/// Breakpoints for guardian adaptive layout (aligned with teacher).
abstract final class PrototypeBreakpoints {
  /// Compact → medium: switch bottom nav to [NavigationRail].
  static const double compact = 600;

  /// Medium → expanded: list tabs open detail in a right overlay drawer.
  static const double expanded = 1000;

  /// Max content width when the main column is unconstrained.
  static const double maxContentWidth = 840;

  static bool useNavigationRail(double width) => width >= compact;

  /// Right overlay detail drawer for nested list routes.
  static bool useDetailDrawer(double width) => width >= expanded;

  static bool detailDrawerActive(BuildContext context) => useDetailDrawer(MediaQuery.sizeOf(context).width);

  /// @Deprecated Use [useDetailDrawer].
  static bool useMasterDetail(double width) => useDetailDrawer(width);
}
