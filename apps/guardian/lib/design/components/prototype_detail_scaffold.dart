import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell_tabs.dart';
import '../colors.dart';

class PrototypeDetailScaffold extends StatelessWidget {
  const PrototypeDetailScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.fallbackRoute = '/home',
    this.embedded = true,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final String fallbackRoute;

  /// Overlay toolbar (close). When false, uses a nested back AppBar.
  final bool embedded;

  static void popOrGo(BuildContext context, {required String fallbackRoute}) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final hub = GuardianShellScope.maybeOf(context)?.hubPath;
    context.go(hub ?? fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return ColoredBox(
        color: PrototypeColors.background,
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
                    tooltip: 'Fermer',
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
      backgroundColor: PrototypeColors.background,
      appBar: AppBar(
        backgroundColor: PrototypeColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () => popOrGo(context, fallbackRoute: fallbackRoute),
        ),
        title: titleWidget ?? (title != null ? Text(title!) : null),
      ),
      body: body,
    );
  }
}
