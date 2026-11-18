import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../breakpoints.dart';
import '../../app/workspace_shell.dart';

class PrototypeDetailScaffold extends StatelessWidget {
  const PrototypeDetailScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.fallbackRoute = '/home',
    this.embedded,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final String fallbackRoute;

  /// Drawer close toolbar when true; full-page back AppBar when false.
  /// Null follows the expanded (≥ 1000) breakpoint.
  final bool? embedded;

  static void popOrGo(BuildContext context, {required String fallbackRoute}) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    if (WorkspaceHost.present(context)) return body;
    final embedded =
        this.embedded ?? PrototypeBreakpoints.detailDrawerActive(context);
    if (embedded) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.titleLarge!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: titleWidget ?? Text(title ?? ''),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr.closeAction,
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        popOrGo(context, fallbackRoute: fallbackRoute),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.tr.backAction,
          onPressed: () => popOrGo(context, fallbackRoute: fallbackRoute),
        ),
        title: titleWidget ?? (title != null ? Text(title!) : null),
      ),
      body: body,
    );
  }
}
