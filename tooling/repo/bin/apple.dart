import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:edaya_repo/src/release.dart';
import 'package:edaya_repo/src/runtime.dart';

Future<void> main() async {
  try {
    final evidence = await verifyQualifiedRelease('production');
    writeJson(p.join(root, '.release/apple-inputs.json'), evidence);
  } catch (error) {
    stderr.writeln(redact(error.toString()));
    exitCode = 1;
  }
}
