import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_review_environment.dart';
import 'integration_test_lifecycle.dart';

const designReviewRootKey = Key('guardian_design_review_root');

/// Writes a PNG of the current guardian app surface for designer review.
Future<void> captureDesignReviewShot(
  WidgetTester tester,
  File outputFile, {
  required Size logicalSize,
  Duration settleDelay = const Duration(milliseconds: 2000),
  double pixelRatio = designReviewExportPixelRatio,
}) async {
  await tester.binding.setSurfaceSize(logicalSize);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logicalSize;
  await tester.pump();
  await tester.pump(settleDelay);
  drainBenignRenderingExceptions(tester);

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(designReviewRootKey),
  );
  final image = await boundary.toImage(pixelRatio: pixelRatio);

  final expectedWidth = (logicalSize.width * pixelRatio).round();
  final expectedHeight = (logicalSize.height * pixelRatio).round();
  if (image.width != expectedWidth || image.height != expectedHeight) {
    image.dispose();
    throw StateError(
      'Unexpected PNG size ${image.width}x${image.height}, '
      'expected ${expectedWidth}x$expectedHeight',
    );
  }

  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode ${outputFile.path}');
    }
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
  }
}

Directory guardianDesignReviewOutputDirectory() {
  return Directory('design-review');
}

File designReviewShotFile(
  Directory root, {
  required String formFactor,
  required String locale,
  required String slug,
}) {
  return File('${root.path}/$formFactor-$locale/$slug.png');
}
