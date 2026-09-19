import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until [finder] matches or [timeout] is reached.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (tester.any(finder)) {
      return;
    }
  }

  fail('Timed out after ${timeout.inSeconds}s waiting for $finder');
}
