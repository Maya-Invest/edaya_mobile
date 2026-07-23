import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

FlutterExceptionHandler? _previousFlutterErrorHandler;

/// Prepares widget-test rendering so design-review PNGs match the real app.
Future<void> configureDesignReviewEnvironment() async {
  await loadDesignReviewFonts();
  _previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (_isBenignDesignReviewRenderingIssue(message)) {
      return;
    }
    _previousFlutterErrorHandler?.call(details);
  };
}

void resetDesignReviewEnvironment() {
  if (_previousFlutterErrorHandler != null) {
    FlutterError.onError = _previousFlutterErrorHandler!;
    _previousFlutterErrorHandler = null;
  }
}

Future<void> loadDesignReviewFonts() async {
  final nunito = FontLoader('Nunito')
    ..addFont(rootBundle.load('assets/fonts/Nunito-Variable.ttf'));
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([nunito.load(), materialIcons.load()]);
}

bool _isBenignDesignReviewRenderingIssue(String message) {
  return message.contains('overflowed') ||
      message.contains('RenderFlex') ||
      message.contains('A RenderFlex') ||
      message.contains('ListTile background color');
}

/// Clears layout exceptions so a screenshot can still be saved.
void drainBenignRenderingExceptions(WidgetTester tester, {int max = 50}) {
  for (var i = 0; i < max; i++) {
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
