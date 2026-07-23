import 'package:flutter/material.dart';

import 'colors.dart';

/// Provides shell chrome (app bar + student context) for pages and drawer hosts.
class ShellChrome extends InheritedWidget {
  const ShellChrome({
    super.key,
    required this.showHeader,
    required this.header,
    this.appBar,
    required super.child,
  });

  final bool showHeader;
  final Widget header;

  /// When set (tablet rail layout), drawer hosts paint this above content so
  /// the overlay can cover the title as well.
  final PreferredSizeWidget? appBar;

  static ShellChrome? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellChrome>();
  }

  @override
  bool updateShouldNotify(ShellChrome oldWidget) {
    return showHeader != oldWidget.showHeader ||
        header != oldWidget.header ||
        appBar != oldWidget.appBar;
  }
}

/// Paints optional app bar + [ShellChrome.header] above [child] (e.g. Home).
class ShellChromeBody extends StatelessWidget {
  const ShellChromeBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chrome = ShellChrome.maybeOf(context);
    if (chrome == null) return child;

    final appBar = chrome.appBar;
    final showHeader = chrome.showHeader;

    if (appBar == null && !showHeader) return child;

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
        if (showHeader) chrome.header,
        Expanded(child: child),
      ],
    );
  }
}

/// Wraps drawer page content with the student context header.
class ShellChromeDrawerMaster extends StatelessWidget {
  const ShellChromeDrawerMaster({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chrome = ShellChrome.maybeOf(context);
    if (chrome == null || !chrome.showHeader) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chrome.header,
        Expanded(child: child),
      ],
    );
  }
}
