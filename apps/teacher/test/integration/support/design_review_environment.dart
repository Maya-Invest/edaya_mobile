import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

FlutterExceptionHandler? _previousFlutterErrorHandler;
Directory? _fontCacheDirectory;

/// Prepares widget-test rendering so design-review PNGs match the real app.
Future<void> configureDesignReviewEnvironment() async {
  _mockPathProviderForGoogleFonts();
  await loadDesignReviewIconFonts();
  _previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (_isBenignDesignReviewRenderingIssue(message)) {
      return;
    }
    _previousFlutterErrorHandler?.call(details);
  };

  GoogleFonts.config.allowRuntimeFetching = true;
  await GoogleFonts.pendingFonts([
    GoogleFonts.nunito(fontWeight: FontWeight.w400),
    GoogleFonts.nunito(fontWeight: FontWeight.w500),
    GoogleFonts.nunito(fontWeight: FontWeight.w600),
    GoogleFonts.nunito(fontWeight: FontWeight.w700),
    GoogleFonts.nunito(fontWeight: FontWeight.w800),
  ]);
}

void resetDesignReviewEnvironment() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, null);
  _fontCacheDirectory?.deleteSync(recursive: true);
  _fontCacheDirectory = null;

  if (_previousFlutterErrorHandler != null) {
    FlutterError.onError = _previousFlutterErrorHandler!;
    _previousFlutterErrorHandler = null;
  }
}

void _mockPathProviderForGoogleFonts() {
  _fontCacheDirectory = Directory.systemTemp.createTempSync(
    'edaya_teacher_design_review_fonts_',
  );
  final cachePath = _fontCacheDirectory!.path;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, (methodCall) async {
    switch (methodCall.method) {
      case 'getTemporaryDirectory':
      case 'getApplicationSupportDirectory':
      case 'getApplicationDocumentsDirectory':
        return cachePath;
      default:
        return null;
    }
  });
}

Future<void> loadDesignReviewIconFonts() async {
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await materialIcons.load();
}

bool _isBenignDesignReviewRenderingIssue(String message) {
  return message.contains('overflowed') ||
      message.contains('RenderFlex') ||
      message.contains('A RenderFlex');
}

/// Clears layout exceptions so a screenshot can still be saved.
void drainBenignRenderingExceptions(WidgetTester tester) {
  while (true) {
    final exception = tester.takeException();
    if (exception == null) {
      return;
    }
    final message = exception.toString();
    if (!_isBenignDesignReviewRenderingIssue(message)) {
      throw exception;
    }
  }
}
