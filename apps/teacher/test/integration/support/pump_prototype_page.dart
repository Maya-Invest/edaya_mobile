import 'package:flutter_test/flutter_test.dart';

import 'integration_test_lifecycle.dart';
import 'prototype_widget_test_harness.dart';

Future<void> pumpPrototypeApp(
  WidgetTester tester,
  PrototypeWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await configureDesignReviewViewport(tester, formFactor);
  harness.viewportSize = designReviewLogicalSize(formFactor);

  await tester.pumpWidget(harness.designReviewRoot(child: harness.buildApp()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> pumpPrototypeRoute(
  WidgetTester tester,
  PrototypeWidgetTestHarness harness, {
  required String location,
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpPrototypeApp(tester, harness, formFactor: formFactor);
  harness.router.go(location);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 40,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}
