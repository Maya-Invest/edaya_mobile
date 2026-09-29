import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_review_environment.dart';
import 'integration_test_lifecycle.dart';

const designReviewRootKey = Key('guardian_prototype_design_review_root');

/// Writes a PNG of the current prototype app surface for designer review.
Future<void> captureDesignReviewShot(
  WidgetTester tester,
  File outputFile, {
  required Size logicalSize,
  Duration settleDelay = const Duration(milliseconds: 300),
  double pixelRatio = designReviewExportPixelRatio,
}) async {
  await tester.binding.setSurfaceSize(logicalSize);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logicalSize;
  await tester.pump();
  if (settleDelay > Duration.zero) {
    await tester.pump(settleDelay);
  }
  drainBenignRenderingExceptions(tester);

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(designReviewRootKey),
  );
  final image = await boundary.toImage(pixelRatio: pixelRatio);

  try {
    final expectedWidth = (logicalSize.width * pixelRatio).round();
    final expectedHeight = (logicalSize.height * pixelRatio).round();
    if (image.width != expectedWidth || image.height != expectedHeight) {
      throw StateError(
        'Unexpected PNG size ${image.width}x${image.height}, '
        'expected ${expectedWidth}x$expectedHeight',
      );
    }

    late ByteData? byteData;
    await tester.runAsync(() async {
      byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    });
    if (byteData == null) {
      throw StateError('Failed to encode ${outputFile.path}');
    }

    // Async file I/O can deadlock after [WidgetTester.runAsync]; sync write is safe.
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsBytesSync(byteData!.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
  }
}

Directory guardianPrototypeDesignReviewOutputDirectory() {
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
