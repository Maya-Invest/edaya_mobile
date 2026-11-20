import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import '../../live/runtime.dart';
import '../../app/workspace_navigation.dart';

class PrototypeDetailScaffold extends StatelessWidget {
  const PrototypeDetailScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.fallbackRoute = '/home',
    this.embedded = false,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final String fallbackRoute;

  /// When true (right detail drawer), show close instead of back.
  final bool embedded;

  static void popOrGo(BuildContext context, {required String fallbackRoute}) {
    backFromWorkspace(context, fallback: fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.of(context) is ModalBottomSheetRoute) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titleWidget != null || title != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  titleWidget ??
                  Text(title!, style: Theme.of(context).textTheme.titleMedium),
            ),
          Expanded(child: body),
        ],
      );
    }
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
        toolbarHeight: WorkspacePageHeading.toolbarHeight(
          context,
          hasPicker: prototypeIsLive(context),
        ),
        title:
            titleWidget ??
            WorkspacePageHeading.forAppBar(
              context,
              title: title ?? '',
              picker: prototypeIsLive(context)
                  ? const ClassContextButton()
                  : null,
            ),
      ),
      body: body,
    );
  }
}
