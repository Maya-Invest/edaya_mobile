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

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        flex: picker == null ? 1 : 4,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontSize: EdayaTokens.typeSection),
        ),
      ),
      if (picker != null) ...[
        const SizedBox(width: 8),
        Expanded(flex: 6, child: picker!),
      ],
    ],
  );
}
