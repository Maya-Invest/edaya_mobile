import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import '../features/settings/app_settings_controller.dart';
import '../l10n/l10n_extension.dart';
import 'demo_store.dart';

import 'school_clock.dart';

class DemoHost extends StatefulWidget {
  const DemoHost({
    super.key,
    required this.role,
    required this.initial,
    required this.prepareLive,
    required this.builder,
  });
  final DemoRole role;
  final DemoStore? initial;
  final Future<void> Function() prepareLive;
  final Widget Function(DemoStore?) builder;
  @override
  State<DemoHost> createState() => _DemoHostState();
}

class _DemoHostState extends State<DemoHost> {
  late DemoStore? store = widget.initial;
  bool busy = false;
  String retryLabel = '';
  VoidCallback? retry;
  @override
  void initState() {
    super.initState();
    setClock();
  }

  void setClock() => SchoolClock.sample = store == null
      ? null
      : DateTime.utc(2026, 11, 10, 10, 15);
  Future<void> changeMode(BuildContext from) async {
    if (busy) return;
    retryLabel = from.tr.retry;
    final previous = store;
    if (previous != null &&
        await showDialog<bool>(
              context: from,
              builder: (context) => AlertDialog(
                title: Text(context.tr.demoExit),
                content: Text(context.tr.demoExitDetail),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.tr.demoExit),
                  ),
                ],
              ),
            ) !=
            true) {
      return;
    }
    if (!mounted || busy) return;
    await switchSession(previous);
  }

  Future<void> switchSession(DemoStore? previous) async {
    setState(() {
      busy = true;
      retry = null;
    });
    try {
      if (previous == null) {
        store ??= await DemoStore.start(widget.role);
      } else {
        // Remove route controllers before clearing their session's storage.
        await WidgetsBinding.instance.endOfFrame;
        await previous.erase();
        store = null;
        await widget.prepareLive();
      }
      await AppSettingsController.preload(prefix: store?.prefix ?? '');
      setClock();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      retry = () => switchSession(previous);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DemoAccess(
    store: store,
    change: changeMode,
    child: busy || retry != null
        ? MaterialApp(
            home: Scaffold(
              body: Center(
                child: busy
                    ? const CircularProgressIndicator()
                    : FilledButton(onPressed: retry, child: Text(retryLabel)),
              ),
            ),
          )
        : KeyedSubtree(key: ValueKey(store?.id), child: widget.builder(store)),
  );
}

class DemoAccess extends InheritedWidget {
  const DemoAccess({
    super.key,
    required this.store,
    required this.change,
    required super.child,
  });
  final DemoStore? store;
  final Future<void> Function(BuildContext) change;
  static DemoAccess? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoAccess>();
  @override
  bool updateShouldNotify(DemoAccess oldWidget) => oldWidget.store != store;
}

class DemoButton extends StatelessWidget {
  const DemoButton({super.key});
  @override
  Widget build(BuildContext context) {
    final access = DemoAccess.of(context);
    if (access == null ||
        kIsWeb ||
        ![
          TargetPlatform.iOS,
          TargetPlatform.android,
        ].contains(defaultTargetPlatform)) {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: () => access.change(context),
      child: Text(
        access.store == null ? context.tr.demoTry : context.tr.demoExit,
      ),
    );
  }
}

/// Kept above the Navigator so sheets and detail routes retain the sample date.
class DemoFrame extends StatelessWidget {
  const DemoFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (DemoAccess.of(context)?.store == null) return child;
    final day = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(SchoolClock.now());
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: SafeArea(
            bottom: false,
            child: Center(child: Text('${context.tr.demoLabel} · $day')),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = MediaQuery.of(
                context,
              ).removePadding(removeTop: true);
              return MediaQuery(
                data: viewport.copyWith(size: constraints.biggest),
                child: child,
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<bool> demoActiveInBackground() async {
  // Background FCM runs in a separate isolate with its own preference cache.
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs.containsKey(DemoStore.activeKey);
}
