import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'client.dart';
import 'integration.dart';
import 'runtime.dart';

final nativeStages = {
  for (final platform in ['android', 'ios'])
    for (final app in applicationPaths.keys)
      '${platform}_$app': (platform: platform, app: app),
};

final stages = [
  'quality',
  'unit',
  ...nativeStages.keys,
  for (final suite in integrationSuites) 'integration_$suite',
];
const preparedPath = '.ci-evidence/prepared.json';
const qualifiedPath = '.ci-evidence/qualification.json';
String fileHash(String path) =>
    digest(File(p.join(root, path)).readAsBytesSync());

void requireEqual(Object? actual, Object? expected, String field) {
  if (jsonEncode(actual) != jsonEncode(expected)) {
    throw StateError('Mismatched $field');
  }
}

Future<Map<String, dynamic>> identity(String target) async {
  final env = Platform.environment;
  final sha = commit(await run(['git', 'rev-parse', 'HEAD'], quiet: true));
  requireEqual(sha, env['CI_SOURCE_SHA'] ?? sha, 'checked-out source');
  final client = checkClient();
  return {
    'sourceCommit': sha,
    'backendCommit': client['backendCommit'],
    'environment': environment(target),
    'apiUrl': releaseApiUrl(target),
    'runId': env['GITHUB_RUN_ID'] ?? 'local',
    'attempt': env['GITHUB_RUN_ATTEMPT'] ?? '1',
    'release': env['RELEASE_MODE'] == 'true',
    if (env['RELEASE_MODE'] == 'true')
      'storeBuild': int.parse(env['EDAYA_STORE_BUILD']!),
    'dependencyLockChecksum': fileHash('pubspec.lock'),
    'clientChecksum': fileHash('.generated/client.json'),
  };
}

Future<void> prepareInputs(String target) async {
  final data = await identity(target);
  final lock = File(p.join(root, '.release/pubspec.lock'));
  lock.parent.createSync(recursive: true);
  File(p.join(root, 'pubspec.lock')).copySync(lock.path);
  writeJson(p.join(root, preparedPath), data);
}

Future<Map<String, dynamic>> verifyPrepared(String target) async {
  final data = jsonFile(p.join(root, preparedPath));
  requireEqual(data, await identity(target), 'prepared inputs');
  requireEqual(
    fileHash('.release/pubspec.lock'),
    data['dependencyLockChecksum'],
    'frozen lockfile',
  );
  return data;
}

List<String> buildFiles(String stage, String target, bool release) {
  if (!release) return ['.ci-evidence/native/$stage.json'];
  final build = nativeStages[stage]!;
  final app = build.app;
  final dir = '.release/$app';
  if (build.platform == 'android') {
    return [
      '$dir/manifest.json',
      '$dir/SHA256SUMS',
      '$dir/signatures.json',
      '$dir/android/edaya-$app-$target.aab',
      if (target == 'staging') '$dir/android/edaya-$app-$target.apk',
    ];
  }
  return ['$dir/apple-build.json', '$dir/ios/edaya-$app-$target.ipa'];
}

Map<String, String> stageFiles(String stage, String target, bool release) {
  final paths = switch (stage) {
    _ when nativeStages.containsKey(stage) => buildFiles(
      stage,
      target,
      release,
    ),
    _ when stages.contains(stage) && stage.startsWith('integration_') => [
      suiteEvidencePath(stage.substring('integration_'.length)),
    ],
    'quality' => ['.ci-evidence/staging-runner/summary.json'],
    'unit' => [widgetEvidencePath],
    _ => throw ArgumentError('Unknown qualification stage $stage'),
  };
  return {for (final path in paths) path: fileHash(path)};
}

Future<void> recordStage(String stage, String target) async {
  final input = await verifyPrepared(target);
  final recordPath = '.ci-evidence/stages/$stage.json';
  if (stage == 'unit') {
    requireEqual(
      jsonFile(p.join(root, widgetEvidencePath))['fingerprint'],
      sourceFingerprint(),
      'widget source fingerprint',
    );
  }
  final files = stageFiles(stage, target, input['release'] as bool);
  writeJson(p.join(root, recordPath), {
    'stage': stage,
    'inputs': input,
    'files': files,
  });
  final transfer = Directory(p.join(root, '.ci/transfer', stage));
  if (transfer.existsSync()) transfer.deleteSync(recursive: true);
  for (final path in [recordPath, ...files.keys]) {
    final destination = File(p.join(transfer.path, path));
    destination.parent.createSync(recursive: true);
    File(p.join(root, path)).copySync(destination.path);
  }
}

void requireSuccessfulJobs(Map<String, dynamic> jobs) {
  for (final stage in ['preparation', ...stages]) {
    requireEqual(jobs[stage]?['result'], 'success', '$stage job result');
  }
}

void checkIntegration(
  Map<String, dynamic> results,
  Map<String, dynamic> input,
  String suite,
) {
  requireEqual(results['commit'], input['sourceCommit'], 'integration source');
  requireEqual(
    results['backendCommit'],
    input['backendCommit'],
    'integration backend',
  );
  requireEqual(
    results['clientChecksum'],
    input['clientChecksum'],
    'integration client',
  );
  requireEqual(
    results['lockSha256'],
    input['dependencyLockChecksum'],
    'integration lock',
  );
  final suites = results['suites'];
  if (suites is! Map || suites.length != 1 || !suites.containsKey(suite)) {
    throw StateError('Expected evidence for $suite only');
  }
  final result = suites[suite];
  final counts = result?['counts'];
  if (result?['passed'] != true ||
      counts?['total'] is! int ||
      counts['total'] <= 0 ||
      counts['passed'] != counts['total']) {
    throw StateError('Incomplete integration suite $suite');
  }
}

void validateStage(
  Map<String, dynamic> record,
  String stage,
  Map<String, dynamic> input,
  Map<String, String> files,
) {
  requireEqual(record['inputs'], input, '$stage inputs');
  requireEqual(record['stage'], stage, 'stage name');
  requireEqual(record['files'], files, '$stage evidence files');
}

Future<void> finalize(String target) async {
  requireSuccessfulJobs(
    jsonDecode(Platform.environment['JOB_RESULTS']!) as Map<String, dynamic>,
  );
  final input = await verifyPrepared(target);
  final artifacts = <String, dynamic>{};
  for (final stage in stages) {
    final record = jsonFile(p.join(root, '.ci-evidence/stages/$stage.json'));
    final files = stageFiles(stage, target, input['release'] as bool);
    validateStage(record, stage, input, files);
    if (nativeStages.containsKey(stage)) artifacts[stage] = files;
  }
  for (final suite in integrationSuites) {
    checkIntegration(
      jsonFile(p.join(root, suiteEvidencePath(suite))),
      input,
      suite,
    );
  }
  writeJson(p.join(root, qualifiedPath), {
    ...input,
    'checks': {'verification': true, 'integration': true},
    'artifacts': artifacts,
  });
}

Future<void> verifyPublication(String platform, String target) async {
  final input = await verifyPrepared(target);
  requireEqual(input['release'], true, 'release mode');
  final env = Platform.environment;
  requireEqual(
    env['GITHUB_REF'],
    'refs/heads/${backendBranch(target)}',
    'release branch',
  );
  requireEqual(env['GITHUB_SHA'], input['sourceCommit'], 'release revision');
  final report = jsonFile(p.join(root, qualifiedPath));
  for (final entry in input.entries) {
    requireEqual(report[entry.key], entry.value, 'qualified ${entry.key}');
  }
  requireEqual(report['checks'], {
    'verification': true,
    'integration': true,
  }, 'qualification');
  for (final app in releaseApps(Platform.environment['MOBILE_APP'])) {
    final stage = '${platform}_$app';
    requireEqual(
      report['artifacts']?[stage],
      stageFiles(stage, target, true),
      'qualified $stage files',
    );
  }
}

Future<void> validationBuild(String platform, String target) async {
  final api = releaseApiUrl(target);
  if (!['android', 'ios'].contains(platform)) {
    throw ArgumentError('Expected android or ios');
  }
  for (final app in releaseApps(Platform.environment['MOBILE_APP'])) {
    final cwd = p.join(root, applicationPaths[app]!);
    if (platform == 'android' &&
        File(p.join(cwd, 'android/key.properties')).existsSync()) {
      throw StateError(
        'Validation requires a checkout without distribution signing properties',
      );
    }
    await run([
      'flutter',
      'build',
      platform == 'ios' ? 'ios' : 'apk',
      '--release',
      if (platform == 'ios') ...['--no-pub', '--no-codesign'],
      ...releaseDartDefines(target),
    ], cwd: cwd);
    final file = platform == 'ios'
        ? 'build/ios/iphoneos/Runner.app/Runner'
        : 'build/app/outputs/flutter-apk/app-release.apk';
    writeJson(p.join(root, '.ci-evidence/native/${platform}_$app.json'), {
      'environment': target,
      'apiUrl': api,
      'apps': {app: fileHash(p.join(cwd, file))},
    });
  }
}
