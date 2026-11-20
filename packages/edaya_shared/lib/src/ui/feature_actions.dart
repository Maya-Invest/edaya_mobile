import 'package:flutter/material.dart';
import '../l10n/l10n_extension.dart';

class FeatureAction {
  const FeatureAction(
    this.label,
    this.icon,
    this.run, {
    this.subtitle,
    this.disabledReason,
  });
  final String label;
  final IconData icon;
  final VoidCallback? run;
  final String? subtitle, disabledReason;
}

bool phoneActions(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600;

/// The owning panel places this above its own footer, inside the keyboard safe area.
class FeatureActionBar extends StatefulWidget {
  const FeatureActionBar({super.key, required this.actions});
  final List<FeatureAction> actions;
  @override
  State<FeatureActionBar> createState() => _FeatureActionBarState();
}

class _FeatureActionBarState extends State<FeatureActionBar> {
  ValueNotifier<List<FeatureAction>>? openSheet;
  @override
  void didUpdateWidget(FeatureActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sheet = openSheet;
    if (sheet == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && openSheet == sheet) sheet.value = widget.actions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    if (actions.isEmpty || !phoneActions(context))
      return const SizedBox.shrink();
    final single = actions.length == 1;
    final label = single ? actions.first.label : context.tr.workspaceActions;
    Future<void> openActions() async {
      final sheetActions = ValueNotifier(widget.actions);
      openSheet = sheetActions;
      final choice = await showModalBottomSheet<FeatureAction>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          top: false,
          child: ValueListenableBuilder<List<FeatureAction>>(
            valueListenable: sheetActions,
            builder: (context, currentActions, _) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in currentActions)
                    ListTile(
                      enabled: action.run != null,
                      leading: Icon(action.icon),
                      title: Text(action.label),
                      subtitle:
                          action.subtitle != null ||
                              (action.run == null &&
                                  action.disabledReason != null)
                          ? Text(
                              [
                                if (action.subtitle != null) action.subtitle,
                                if (action.run == null &&
                                    action.disabledReason != null)
                                  action.disabledReason,
                              ].join('\n'),
                              style: TextStyle(
                                color: Theme.of(
                                  sheet,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                      onTap: action.run == null
                          ? null
                          : () => Navigator.pop(sheet, action),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      openSheet = null;
      sheetActions.dispose();
      if (context.mounted) choice?.run?.call();
    }

    final callback = single ? actions.first.run : openActions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Theme(
            data: Theme.of(context).copyWith(
              floatingActionButtonTheme: Theme.of(context)
                  .floatingActionButtonTheme
                  .copyWith(
                    extendedSizeConstraints: const BoxConstraints(
                      minHeight: 52,
                    ),
                  ),
            ),
            child: FloatingActionButton.extended(
              heroTag: null,
              tooltip: label,
              onPressed: callback,
              backgroundColor: callback == null
                  ? Theme.of(context).disabledColor
                  : null,
              icon: Icon(single ? actions.first.icon : Icons.more_horiz),
              label: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (box.maxWidth - 80).clamp(40.0, double.infinity),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FeatureActionPanel extends StatelessWidget {
  const FeatureActionPanel({
    super.key,
    required this.actions,
    required this.child,
  });
  final List<FeatureAction> actions;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: child),
      FeatureActionBar(actions: actions),
    ],
  );
}
