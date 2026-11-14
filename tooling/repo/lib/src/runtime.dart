import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'process.dart';
export 'process.dart';

const applicationPaths = {
  'guardian': 'apps/guardian',
  'teacher': 'apps/teacher',
};

String get root {
  var directory = Directory.current.absolute;
  while (!File(p.join(directory.path, 'pubspec.yaml')).existsSync() ||
      !Directory(
        p.join(directory.path, applicationPaths['guardian']!),
      ).existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Run this command inside edaya_mobile');
    }
    directory = parent;
  }
  return directory.path;
}

String backendBranch(String target) => switch (target) {
  'main' || 'production' => 'main',
  'staging' => 'staging',
  _ => throw ArgumentError('Expected main, staging or production'),
};
String environment(String target) => switch (target) {
  'staging' || 'production' => target,
  _ => throw ArgumentError('Expected staging or production'),
};
String commit(String value) {
  if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(value)) {
    throw ArgumentError('Expected immutable backend commit');
  }
  return value;
}

String digest(List<int> bytes) => sha256.convert(bytes).toString();
Future<String> run(
  List<String> command, {
  String? cwd,
  Map<String, String>? env,
  bool quiet = false,
  Duration? timeout = const Duration(minutes: 30),
}) async {
  final result = await executeProcess(
    command,
    cwd: cwd ?? root,
    env: env,
    quiet: quiet,
    timeout: timeout,
  );
  if (result.code != 0 || result.interrupted) {
    throw StateError(
      '${command.first} ${result.interrupted ? 'interrupted or timed out' : 'exited ${result.code}'}',
    );
  }
  return result.output;
}

List<File> files(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return [];
  return (dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path)));
}

Map<String, String> hashes(String directory) => {
  for (final file in files(directory))
    p.relative(file.path, from: directory): digest(file.readAsBytesSync()),
};
void writeJson(String path, Object? value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
  );
}

Map<String, dynamic> jsonFile(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
