import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

FlutterExceptionHandler? _previousFlutterErrorHandler;
final designReviewLayoutIssues = <String>[];

/// Prepares widget-test rendering so design-review PNGs match the real app.
Future<void> configureDesignReviewEnvironment() async {
  await loadDesignReviewFonts();
  _previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (_isBenignDesignReviewRenderingIssue(message)) {
      designReviewLayoutIssues.add(message);
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
  TestWidgetsFlutterBinding.ensureInitialized();
  final loaded = await _loadFontsFromManifest();
  await _loadEdayaUiFonts();
  if (!loaded.contains('MaterialIcons')) {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  }
}

/// [EdayaTypography] looks up `packages/edaya_shared/Inter` (and Poppins).
Future<void> _loadEdayaUiFonts() async {
  const interAssets = [
    'packages/edaya_shared/assets/fonts/Inter-Regular.ttf',
    'packages/edaya_shared/assets/fonts/Inter-Medium.ttf',
    'packages/edaya_shared/assets/fonts/Inter-SemiBold.ttf',
    'packages/edaya_shared/assets/fonts/Inter-Bold.ttf',
  ];
  const poppinsAssets = [
    'packages/edaya_shared/assets/fonts/Poppins-SemiBold.ttf',
  ];
  await Future.wait([
    _loadFamily('Inter', interAssets),
    _loadFamily('packages/edaya_shared/Inter', interAssets),
    _loadFamily('Poppins', poppinsAssets),
    _loadFamily('packages/edaya_shared/Poppins', poppinsAssets),
  ]);
}

Future<Set<String>> _loadFontsFromManifest() async {
  try {
    final raw = await rootBundle.loadString('FontManifest.json');
    final manifest = jsonDecode(raw);
    if (manifest is! List) {
      return {};
    }
    final families = <String>{};
    for (final item in manifest) {
      if (item is! Map) {
        continue;
      }
      final family = item['family'] as String?;
      final fonts = item['fonts'];
      if (family == null || fonts is! List || fonts.isEmpty) {
        continue;
      }
      final loader = FontLoader(family);
      for (final font in fonts) {
        if (font is! Map) {
          continue;
        }
        final asset = font['asset'] as String?;
        if (asset == null) {
          continue;
        }
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
      families.add(family);
    }
    return families;
  } on Object {
    return {};
  }
}

Future<void> _loadFamily(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
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
