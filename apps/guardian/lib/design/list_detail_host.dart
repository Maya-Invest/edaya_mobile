import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'master_detail.dart';

/// Hosts a list [master] with optional nested [detailChild] (GoRouter shell child).
///
/// The hub stays mounted. Compact / medium cover it with a full-width overlay;
/// wide layouts use a right drawer.
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

    return DetailDrawerScaffold(
      master: DetailDrawerMasterColumn(child: master),
      detail: detailChild,
      hasSelection: hasSelection,
      listPath: listPath,
    );
  }
}
