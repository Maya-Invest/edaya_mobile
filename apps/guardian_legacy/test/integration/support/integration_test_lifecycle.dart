import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// PNG scale factor applied on top of the logical viewport during capture.
const designReviewExportPixelRatio = 2.0;

/// Resets the widget tree and Levit state between integration widget tests.
Future<void> resetIntegrationTestSurface(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  Levit.reset();
}

Size designReviewLogicalSize(DesignReviewFormFactor formFactor) {
  return switch (formFactor) {
    DesignReviewFormFactor.phone => const Size(390, 844),
    // Landscape tablet — width triggers the navigation rail (>= 600).
    DesignReviewFormFactor.tablet => const Size(1200, 900),
  };
}

Future<void> configureIntegrationTestViewport(WidgetTester tester) {
  return configureDesignReviewViewport(tester, DesignReviewFormFactor.phone);
}

Future<void> configureDesignReviewViewport(
  WidgetTester tester,
  DesignReviewFormFactor formFactor,
) async {
  final logical = designReviewLogicalSize(formFactor);
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(logical);
  tester.view.physicalSize = logical;
}

enum DesignReviewFormFactor {
  phone('phone'),
  tablet('tablet');

  const DesignReviewFormFactor(this.slug);

  final String slug;
}

Future<void> resetIntegrationTestViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(null);
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}
