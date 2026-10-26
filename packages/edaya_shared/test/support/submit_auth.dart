import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises explicit terms acceptance when the isolated API requires it.
Future<void> submitAuth(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  final submit = find.byKey(const Key('auth-submit'));
  while (DateTime.now().isBefore(deadline)) {
    final acceptance = find.byKey(const Key('auth-terms-accept'));
    if (tester.any(acceptance)) {
      final checkbox = tester.widget<CheckboxListTile>(acceptance);
      if (checkbox.onChanged != null && checkbox.value != true) {
        await tester.ensureVisible(acceptance);
        await tester.tap(acceptance);
        await tester.pump();
      }
    }
    if (tester.any(submit) &&
        tester.widget<FilledButton>(submit).onPressed != null) {
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail(
    'Authentication submit remained unavailable; inspect terms loading and acceptance.',
  );
}
