import 'dart:convert';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'client.dart';
import 'runtime.dart';

Future<Map<String, dynamic>> verifyQualifiedRelease(String target) async {
  environment(target);
  if ((await run(['git', 'status', '--porcelain'], quiet: true)).isNotEmpty) {
    throw StateError('Deployment requires an unchanged qualified checkout');
  }
  final evidence = jsonFile(p.join(root, '.ci-evidence/qualification.json'));
  if (evidence['environment'] != target ||
      evidence['sourceCommit'] !=
          await run(['git', 'rev-parse', 'HEAD'], quiet: true) ||
      evidence['dependencyLockChecksum'] !=
          digest(File(p.join(root, 'pubspec.lock')).readAsBytesSync()) ||
      evidence['checks']['verification'] != true ||
      evidence['checks']['integration'] != true ||
      jsonEncode(evidence['client']) != jsonEncode(checkClient())) {
    throw StateError('Release does not match qualified source/client');
  }
  return evidence;
}
