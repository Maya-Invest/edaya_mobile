import 'dart:convert';
import 'dart:io';

/// Reads only the injected local transport mailbox; never contacts a provider.
Future<String> capturedOtp(
  String destination,
  String channel,
  DateTime since,
) async {
  final path = Platform.environment['EDAYA_TEST_OTP_FILE'];
  if (path == null || path.isEmpty) {
    throw StateError('Required OTP transport capture is not configured');
  }
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    final file = File(path);
    if (await file.exists()) {
      final rows = (await file.readAsLines())
          .where((line) => line.isNotEmpty)
          .map((line) => jsonDecode(line) as Map<String, dynamic>);
      final match = rows
          .where(
            (row) =>
                row['destination'] == destination &&
                row['channel'] == channel &&
                (row['deliveredAt'] as int) >= since.millisecondsSinceEpoch,
          )
          .lastOrNull;
      if (match != null) return match['code'] as String;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('Required captured OTP was not delivered through $channel');
}
