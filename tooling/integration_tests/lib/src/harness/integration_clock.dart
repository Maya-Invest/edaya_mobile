import 'dart:io';

/// Advances only the injected disposable Identity fixture clock.
Future<void> setIntegrationClockOffset(Duration offset) async {
  final path = Platform.environment['EDAYA_TEST_CLOCK_FILE'];
  if (path == null || path.isEmpty) {
    throw StateError('Integration clock is required');
  }
  await File(path).writeAsString(offset.inMilliseconds.toString());
}
