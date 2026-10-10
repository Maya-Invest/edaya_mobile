import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_review_environment.dart';
import 'design_review_config.dart';
import 'integration_test_lifecycle.dart';

const designReviewRootKey = Key('teacher_design_review_root');

/// Writes a PNG of the current teacher app surface for designer review.
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
  // Decode bundled brand artwork before exporting the first frame. Fake test
  // time alone does not wait for asynchronous asset decoding.
  for (final element in find.byType(Image).evaluate()) {
    final image = element.widget as Image;
    if (image.image is AssetImage) {
      await tester.runAsync(() => precacheImage(image.image, element));
    }
  }
  await tester.pump();
  drainBenignRenderingExceptions(tester);

  if (logicalSize.width == 390 &&
      Platform.environment['EDAYA_DESIGN_REVIEW_A11Y'] == '1') {
    final report = <String, Object?>{};
    for (final entry in {
      'textContrast': textContrastGuideline,
      'androidTapTargets': androidTapTargetGuideline,
      'labeledTapTargets': labeledTapTargetGuideline,
    }.entries) {
      final result = await entry.value.evaluate(tester);
      report[entry.key] = {'passed': result.passed, 'reason': result.reason};
    }
    outputFile.parent.createSync(recursive: true);
    File(
      '${outputFile.path}.a11y.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    if (Platform.environment['EDAYA_DESIGN_REVIEW_STRICT'] == '1') {
      for (final entry in report.entries) {
        final result = entry.value as Map<String, Object?>;
        expect(
          result['passed'],
          isTrue,
          reason: '${outputFile.path}: ${entry.key}: ${result['reason']}',
        );
      }
    }
  }

  if (designReviewLayoutIssues.isNotEmpty) {
    outputFile.parent.createSync(recursive: true);
    File(
      '${outputFile.path}.layout.json',
    ).writeAsStringSync(jsonEncode(designReviewLayoutIssues));
    final issues = List<String>.of(designReviewLayoutIssues);
    designReviewLayoutIssues.clear();
    if (Platform.environment['EDAYA_DESIGN_REVIEW_STRICT'] == '1') {
      fail('${outputFile.path}: ${issues.join('\n')}');
    }
  }
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

Directory teacherPrototypeDesignReviewOutputDirectory() {
  return Directory(designReviewOutputPath());
}

File designReviewShotFile(
  Directory root, {
  required String formFactor,
  required String locale,
  required String slug,
}) {
  return File('${root.path}/$formFactor-$locale/$slug.png');
}
