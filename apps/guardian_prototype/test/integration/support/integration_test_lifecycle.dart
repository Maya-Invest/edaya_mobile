import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PNG scale factor applied on top of the logical viewport during capture.
const designReviewExportPixelRatio = 2.0;

/// Resets the widget tree between design-review captures.
Future<void> resetIntegrationTestSurface(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Size designReviewLogicalSize(DesignReviewFormFactor formFactor) {
  return switch (formFactor) {
    DesignReviewFormFactor.phone => const Size(390, 844),
    // Medium: navigation rail, no detail drawer (600 ≤ width < 1000).
    DesignReviewFormFactor.medium => const Size(800, 1024),
    DesignReviewFormFactor.tablet => const Size(1200, 900),
  };
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
  medium('medium'),
  tablet('tablet');

  const DesignReviewFormFactor(this.slug);

  final String slug;
}

Future<void> resetIntegrationTestViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(null);
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}
