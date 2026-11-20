import 'package:flutter/material.dart';
import '../app/edaya_tokens.g.dart';
import 'package:go_router/go_router.dart';

/// Route-backed feature tabs. Each panel retains its scroll and controller state.
class WorkspaceTabs extends StatefulWidget {
  const WorkspaceTabs({
    super.key,
    required this.labels,
    required this.values,
    required this.children,
    this.parameter = 'tab',
  });

  final List<String> labels, values;
  final List<Widget> children;
  final String parameter;

  @override
  State<WorkspaceTabs> createState() => _WorkspaceTabsState();
}

class _WorkspaceTabsState extends State<WorkspaceTabs>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  @override
  void initState() {
    super.initState();
    tabs = TabController(length: widget.labels.length, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  int localIndex = 0;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final uri = router == null ? null : GoRouterState.of(context).uri;
    final requested = widget.values.indexOf(
      uri?.queryParameters[widget.parameter] ?? '',
    );
    final index = uri == null
        ? localIndex
        : requested < 0
        ? 0
        : requested;
    if (tabs.index != index) tabs.index = index;
    return Column(
      children: [
        TabBar(
          controller: tabs,
          isScrollable: MediaQuery.textScalerOf(context).scale(14) > 22,
          onTap: (next) {
            if (uri == null) {
              setState(() => localIndex = next);
            } else {
              context.replace(
                uri
                    .replace(
                      queryParameters: {
                        ...uri.queryParameters,
                        widget.parameter: widget.values[next],
                      },
                    )
                    .toString(),
              );
            }
          },
          tabs: [for (final label in widget.labels) Tab(text: label)],
        ),
        Expanded(
          child: IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < widget.children.length; i++)
                TickerMode(enabled: index == i, child: widget.children[i]),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact feature heading; Home deliberately keeps its existing app bar.
class WorkspacePageHeading extends StatelessWidget {
  const WorkspacePageHeading({super.key, required this.title, this.picker});
  final String title;
  final Widget? picker;

  /// Flutter caps AppBar title scaling. Restore the surrounding system scaler
  /// so the title and the picker use the same measurements as the toolbar.
  static Widget forAppBar(
    BuildContext context, {
    required String title,
    Widget? picker,
  }) {
    return MediaQuery(
      data: MediaQuery.of(context),
      child: WorkspacePageHeading(title: title, picker: picker),
    );
  }

  static bool stacked(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 &&
      MediaQuery.textScalerOf(context).scale(EdayaTokens.typeFeatureTitle) >=
          27;

  static double toolbarHeight(BuildContext context, {bool hasPicker = true}) {
    final line = MediaQuery.textScalerOf(
      context,
    ).scale(EdayaTokens.typeFeatureTitle);
    return hasPicker && stacked(context) ? line * 2.7 + 30 : line + 38;
  }

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontSize: EdayaTokens.typeFeatureTitle),
    );
    if (picker == null) return heading;
    if (stacked(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [heading, picker!],
      );
    }
    return LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * .55),
            child: heading,
          ),
          const SizedBox(width: 8),
          Expanded(child: picker!),
        ],
      ),
    );
  }
}

class WorkspacePickerButton extends StatelessWidget {
  const WorkspacePickerButton({
    super.key,
    required this.name,
    required this.icon,
    required this.onPressed,
  });
  final String name;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: onPressed,
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            semanticsLabel: name,
          ),
        ),
      ],
    ),
  );
}
