import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'breakpoints.dart';
import 'colors.dart';
import 'shell_chrome.dart';

/// Full-width [master] with an overlay [detail].
///
/// Compact / medium: the detail covers the hub. Expanded (≥ 1000): right drawer.
class DetailDrawerScaffold extends StatelessWidget {
  const DetailDrawerScaffold({
    super.key,
    required this.master,
    required this.detail,
    required this.hasSelection,
    required this.listPath,
    this.widthFraction = 0.4,
  });

  final Widget master;
  final Widget detail;
  final bool hasSelection;
  final String listPath;
  final double widthFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!hasSelection) return master;

        final useDrawer =
            PrototypeBreakpoints.useDetailDrawer(constraints.maxWidth);
        if (!useDrawer) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: master),
              Positioned.fill(
                child: Material(
                  color: PrototypeColors.background,
                  child: detail,
                ),
              ),
            ],
          );
        }

        final drawerWidth = math.min(
          math.max(constraints.maxWidth * widthFraction, 360.0),
          math.min(constraints.maxWidth * 0.5, 520.0),
        ).toDouble();

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: master),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go(listPath),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: drawerWidth,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.zero,
                clipBehavior: Clip.hardEdge,
                color: PrototypeColors.background,
                shadowColor: Colors.black26,
                child: detail,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Master column for tablet drawers: optional app bar + student context + page.
class DetailDrawerMasterColumn extends StatelessWidget {
  const DetailDrawerMasterColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chrome = ShellChrome.maybeOf(context);
    final appBar = chrome?.appBar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (appBar != null)
          Material(
            color: PrototypeColors.background,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: appBar.preferredSize.height,
                child: appBar,
              ),
            ),
          ),
        Expanded(child: ShellChromeDrawerMaster(child: child)),
      ],
    );
  }
}
