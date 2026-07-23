import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'breakpoints.dart';
import 'master_detail.dart';

/// Hosts a list [master] with optional nested [detailChild] (GoRouter shell child).
///
/// Compact / medium (&lt; expanded): list or detail under shell chrome (brand app
/// bar when present + student context).
/// Wide (≥ [PrototypeBreakpoints.expanded]): list stays full-width; detail opens
/// as a full-height right overlay (title bar to bottom, beside the rail).
class ListDetailHost extends StatelessWidget {
  const ListDetailHost({
    super.key,
    required this.listPath,
    required this.master,
    required this.detailChild,
    this.isListPath,
  });

  /// Path to navigate to when closing the drawer (e.g. `/fees`, `/inbox`).
  final String listPath;
  final Widget master;
  final Widget detailChild;

  /// When set, overrides the default “path == listPath” list detection.
  final bool Function(String path)? isListPath;

  bool _isList(String path) => isListPath?.call(path) ?? path == listPath;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final hasSelection = !_isList(path);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer =
            PrototypeBreakpoints.useDetailDrawer(constraints.maxWidth);

        if (!useDrawer) {
          // Always keep brand app bar (medium+) + student context above content.
          return DetailDrawerMasterColumn(
            child: hasSelection ? detailChild : master,
          );
        }

        return DetailDrawerScaffold(
          master: DetailDrawerMasterColumn(child: master),
          detail: detailChild,
          hasSelection: hasSelection,
          listPath: listPath,
        );
      },
    );
  }
}
