import 'dart:io';
import 'package:path/path.dart' as p;
import 'runtime.dart';
import 'integration.dart';

const requiredScenarios = [
  'staging.identity.email-only',
  'staging.identity.no-test-access',
  'staging.teacher.subject',
  'staging.teacher.homeroom',
  'staging.guardian.ci-g1',
  'staging.guardian.ci-g4',
];
List<String> smokePreflight(Map<String, String> env) {
  final errors = <String>[];
  if (env['EDAYA_API_URL'] != 'https://staging.api.edayaplus.com') {
    errors.add('Recorded staging URL required');
  }
  if ((env['TEST_OTP_ACCESS'] ?? 'false') != 'false' ||
      [
        'EDAYA_TEST_OTP_FILE',
        'EDAYA_TEST_CLOCK_FILE',
      ].any((key) => (env[key] ?? '').isNotEmpty)) {
    errors.add('OTP capture and test clock forbidden in staging smoke');
  }
  try {
    final file = File(env['SEED_AUTH_SESSIONS_FILE'] ?? '');
    if (file.statSync().mode & 0x3f != 0) {
      throw StateError('Session file must be private');
    }
    final sessions = jsonFile(file.path);
    for (final email in [
      'a.toure@ecole-ci.edaya.dev',
      'k.diomande@ecole-ci.edaya.dev',
      'm.kone@mail.ci',
      'k.yao@mail.ci',
    ]) {
      if (sessions[email] is! String || (sessions[email] as String).isEmpty) {
        throw StateError('Missing session');
      }
    }
  } catch (_) {
    errors.add('Valid private fixture sessions required (mode 0600)');
  }
  return errors;
}

Future<void> stagingSmoke({bool validateRunner = false}) async {
  if (!validateRunner) {
    final errors = smokePreflight(Platform.environment);
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
  }
  final lines = <String>[];
  final result = await executeProcess(
    [
      'dart',
      '-DTEST_OTP_ACCESS=false',
      'test',
      'test/staging',
      '--tags',
      'staging',
      '--reporter',
      'json',
    ],
    cwd: p.join(root, 'tooling/integration_tests'),
    quiet: true,
    onLine: lines.add,
    env: {
      'TEST_OTP_ACCESS': 'false',
      'EDAYA_STAGING_VALIDATE_ONLY': '$validateRunner',
    },
  );
  final report = evaluate(lines, result.code, requiredScenarios);
  final directory = p.join(
    root,
    '.ci-evidence',
    validateRunner ? 'staging-runner' : 'staging-smoke',
  );
  writeJson(p.join(directory, 'summary.json'), report);
  if (report['ok'] != true) throw StateError('Staging smoke failed');
}
