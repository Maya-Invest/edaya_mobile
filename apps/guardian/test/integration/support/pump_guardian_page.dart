import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guardian_widget_test_harness.dart';
import 'pump_until_found.dart';

/// Pumps [page] inside the guardian integration harness and waits for it to mount.
///
/// Pages are wrapped in a [Scaffold] so material widgets (dropdowns, etc.) match
/// production layout inside [AppShellPage].
Future<void> pumpGuardianPage<T extends Widget>(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
  T page,
) async {
  await tester.pumpWidget(harness.buildApp(Scaffold(body: page)));
  await pumpUntilFound(tester, find.byType(T));
}

/// Pumps the authenticated router shell and waits until [page] is visible.
Future<void> pumpGuardianShellUntil<T extends Widget>(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
) async {
  await tester.pumpWidget(harness.buildRouterApp());
  await pumpUntilFound(tester, find.byType(T));
}

/// Taps a [SegmentedButton] segment identified by [label].
Future<void> tapSegmentLabel(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}
