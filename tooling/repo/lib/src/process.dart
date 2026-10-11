import 'dart:async';
import 'dart:convert';
import 'dart:io';

String redact(String text, {Map<String, String>? environment}) {
  for (final entry in {...Platform.environment, ...?environment}.entries) {
    if (RegExp(
      r'SECRET|TOKEN|PASSWORD|SIGNING_BUNDLE|PRIVATE_KEY',
    ).hasMatch(entry.key)) {
      for (final value
          in entry.value.split('\n').where((value) => value.length > 4)) {
        text = text.replaceAll(value, '[REDACTED]');
      }
    }
  }
  return text
      .replaceAll(
        RegExp(r'(?:https?|postgres(?:ql)?)://[^/\s@]+@'),
        'https://[REDACTED]@',
      )
      .replaceAll(
        RegExp(r'''(?:Bearer|Basic)\s+[^\s"']+''', caseSensitive: false),
        'Bearer [REDACTED]',
      )
      .replaceAllMapped(
        RegExp(
          r'''((?:password|secret|token|authorization|cookie|otp|code|recoveryCode)["\s]*[:=]\s*["']?)[^\s"',}]+''',
          caseSensitive: false,
        ),
        (m) => '${m[1]}[REDACTED]',
      )
      .replaceAll(
        RegExp(r'''/invite/(?!:token)[^\s/?"']+'''),
        '/invite/[REDACTED]',
      )
      .replaceAll(RegExp(r'(?<!\d)\d{6}(?!\d)'), '[REDACTED]');
}

/// Capture one process with identical timeout/cancellation cleanup for every caller.
Future<({int code, bool interrupted, String output})> executeProcess(
  List<String> command, {
  String? cwd,
  Map<String, String>? env,
  bool quiet = false,
  Duration? timeout = const Duration(minutes: 30),
  void Function(String)? onLine,
}) async {
  if (command.isEmpty) throw ArgumentError('Empty command');
  final Process process;
  try {
    process = await Process.start(
      command.first,
      command.skip(1).toList(),
      workingDirectory: cwd,
      environment: env,
      runInShell: false,
    );
  } catch (_) {
    throw StateError('Could not start ${command.first}');
  }
  final output = StringBuffer();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  var interrupted = false;
  Future<void>? stopping;
  Future<void> stopTree() async {
    // ps exposes only parent/child IDs. Kill descendants before the parent can orphan them.
    final descendants = <int>[];
    try {
      final snapshot = await Process.run('ps', [
        '-ax',
        '-o',
        'pid=,ppid=',
      ]).timeout(const Duration(seconds: 2));
      final parents = <int, int>{};
      if (snapshot.exitCode == 0) {
        for (final line in (snapshot.stdout as String).split('\n')) {
          final values = line.trim().split(RegExp(r'\s+'));
          if (values.length == 2) {
            final pid = int.tryParse(values[0]),
                parent = int.tryParse(values[1]);
            if (pid != null && parent != null) parents[pid] = parent;
          }
        }
        void collect(int parent) {
          for (final pid in parents.keys.where(
            (pid) => parents[pid] == parent,
          )) {
            collect(pid);
            descendants.add(pid);
          }
        }

        collect(process.pid);
      }
    } catch (_) {
      /* Still terminate the owned process if process inventory is unavailable. */
    }
    for (final pid in [...descendants, process.pid]) {
      Process.killPid(pid, ProcessSignal.sigterm);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final pid in [...descendants, process.pid]) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  }

  void stop() {
    interrupted = true;
    stopping ??= stopTree();
  }

  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    subscriptions.add(signal.watch().listen((_) => stop()));
  }
  final timer = timeout == null ? null : Timer(timeout, stop);
  final reads = [
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          output.writeln(line);
          onLine?.call(line);
          if (!quiet) stdout.writeln(redact(line, environment: env));
        }),
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          onLine?.call(line);
          if (!quiet) stderr.writeln(redact(line, environment: env));
        }),
  ];
  try {
    final code = await process.exitCode;
    await Future.wait(reads);
    if (stopping != null) await stopping;
    return (
      code: interrupted ? 124 : code,
      interrupted: interrupted,
      output: output.toString().trim(),
    );
  } finally {
    timer?.cancel();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
}
