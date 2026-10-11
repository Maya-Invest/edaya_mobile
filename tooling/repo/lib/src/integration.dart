import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'runtime.dart';
import 'client.dart';

Map<String, dynamic> evaluate(
  Iterable<String> lines,
  int exitCode,
  List<String> required,
) {
  final tests = <int, String>{}, outcomes = <int, Map<String, dynamic>>{};
  final errors = <String>[], completed = <bool>[];
  List<String>? routes;
  var inventories = 0;
  for (final line in lines) {
    dynamic event;
    try {
      event = jsonDecode(line);
    } catch (_) {
      continue;
    }
    if (event is! Map<String, dynamic>) continue;
    switch (event['type']) {
      case 'testStart':
        final test = event['test'] as Map<String, dynamic>;
        if (test['line'] != null &&
            !RegExp(
              r'\((?:setUpAll|tearDownAll)\)$',
            ).hasMatch(test['name'] as String)) {
          tests[test['id'] as int] = test['name'] as String;
        }
      case 'testDone':
        outcomes[event['testID'] as int] = event;
      case 'error':
        errors.add(redact('${event['error']}'));
      case 'done':
        completed.add(event['success'] == true);
      case 'print':
        final message = '${event['message']}';
        if (message.startsWith('EDAYA_ROUTE_INVENTORY:')) {
          inventories++;
          routes =
              (jsonDecode(message.substring('EDAYA_ROUTE_INVENTORY:'.length))
                      as List)
                  .cast<String>();
        }
    }
  }
  final scenarios = tests.entries.map((entry) {
    final outcome = outcomes[entry.key];
    return <String, dynamic>{
      'id': RegExp(r'\[([a-z0-9][a-z0-9.-]+)\]').firstMatch(entry.value)?[1],
      'name': entry.value,
      'status': outcome == null
          ? 'blocked'
          : outcome['skipped'] == true
          ? 'skipped'
          : outcome['result'] == 'success'
          ? 'passed'
          : 'failed',
    };
  }).toList();
  final ids = scenarios.map((row) => row['id']).toList();
  final problems = <String>[
    if (exitCode != 0) 'child process exited $exitCode',
    if (tests.isEmpty) 'zero executable tests discovered',
    if (completed.isEmpty || completed.contains(false))
      'missing or unsuccessful runner completion',
    if (scenarios.any((row) => row['status'] != 'passed'))
      'failed, blocked, or skipped tests',
    if (errors.isNotEmpty) 'runner reported errors',
    if (required.any((id) => !ids.contains(id))) 'missing required scenarios',
    if (ids.any((id) => !required.contains(id)))
      'unregistered executable scenarios',
    if (ids.length != ids.toSet().length) 'duplicate executed scenario IDs',
  ];
  return {
    'ok': problems.isEmpty,
    'tests': scenarios,
    'problems': problems,
    'errors': errors,
    'routes': inventories == 1 ? routes : null,
  };
}

List<String> featureProblems(
  Map<String, dynamic> contract,
  List<String> registered,
  List<String>? routes,
) {
  final problems = <String>[], ids = <String>[], paths = <String>[];
  for (final feature in contract['features'] as List) {
    ids.add(feature['id'] as String);
    paths.addAll((feature['routes'] as List).cast<String>());
    if ((feature['actions'] as List).isEmpty) {
      problems.add('feature has no actions');
    }
    for (final action in feature['actions'] as List) {
      ids.add(action['id'] as String);
      final scenarios = (action['scenarios'] as List).cast<String>();
      if (scenarios.isEmpty ||
          scenarios.any((id) => !registered.contains(id))) {
        problems.add('missing or unregistered action scenarios');
      }
    }
  }
  if (ids.length != ids.toSet().length) {
    problems.add('duplicate feature/action IDs');
  }
  if (paths.length != paths.toSet().length) {
    problems.add('duplicate registered routes');
  }
  if (routes == null) {
    problems.add('missing executed GoRouter inventory');
  } else if (routes.toSet().difference(paths.toSet()).isNotEmpty ||
      paths.toSet().difference(routes.toSet()).isNotEmpty) {
    problems.add('GoRouter inventory differs from feature registry');
  }
  return problems;
}

String sourceFingerprint() {
  final inputs = <String, String>{};
  for (final parent in ['apps', 'packages', 'tooling']) {
    for (final entry in Directory(
      p.join(root, parent),
    ).listSync().whereType<Directory>()) {
      for (final directory in ['lib', 'test', 'bin']) {
        for (final file in files(
          p.join(entry.path, directory),
        ).where((file) => file.path.endsWith('.dart'))) {
          inputs[p.relative(file.path, from: root)] = digest(
            file.readAsBytesSync(),
          );
        }
      }
      final pubspec = File(p.join(entry.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        inputs[p.relative(pubspec.path, from: root)] = digest(
          pubspec.readAsBytesSync(),
        );
      }
    }
  }
  for (final path in [
    'pubspec.lock',
    '.generated/client.json',
    'tooling/integration_tests/features.json',
    'tooling/integration_tests/scenarios.json',
  ]) {
    inputs[path] = digest(File(p.join(root, path)).readAsBytesSync());
  }
  return digest(
    utf8.encode(
      jsonEncode(
        Map.fromEntries(
          inputs.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        ),
      ),
    ),
  );
}

Future<void> integration({String? suite, bool validateOnly = false}) async {
  checkClient();
  final registry = jsonFile(
    p.join(root, 'tooling/integration_tests/scenarios.json'),
  );
  final allIds = registry.values
      .expand((value) => (value as List).cast<String>())
      .toList();
  if (registry.keys.toSet().difference({
        'api',
        'guardian',
        'teacher',
      }).isNotEmpty ||
      registry.length != 3 ||
      registry.values.any((value) => (value as List).isEmpty) ||
      allIds.length != allIds.toSet().length ||
      allIds.any((id) => !RegExp(r'^[a-z0-9][a-z0-9.-]+$').hasMatch(id))) {
    throw StateError('Invalid integration scenario registry');
  }
  final features = jsonFile(
    p.join(root, 'tooling/integration_tests/features.json'),
  );
  final directory = Directory(p.join(root, '.integration-results'))
    ..createSync(recursive: true);
  final summaries = <String, dynamic>{};
  for (final name in suite == null ? registry.keys : [suite]) {
    if (!registry.containsKey(name)) throw ArgumentError('Unknown suite');
    final log = File(p.join(directory.path, '$name.jsonl')),
        metadata = File(p.join(directory.path, '$name.run.json')),
        exitFile = File(p.join(directory.path, '$name.exit.json'));
    final fingerprint = sourceFingerprint();
    if (!validateOnly) {
      writeJson(metadata.path, {
        'fingerprint': fingerprint,
        'completed': false,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      });
      final command = name == 'api'
          ? [
              'dart',
              '-DTEST_OTP_ACCESS=true',
              'test',
              '--tags',
              'integration',
              '--reporter',
              'json',
            ]
          : [
              'flutter',
              'test',
              '--no-pub',
              'test/integration',
              '--tags',
              'integration',
              '--concurrency=1',
              '--dart-define=TEST_OTP_ACCESS=true',
              '--machine',
            ];
      final cwd = p.join(
        root,
        name == 'api' ? 'tooling/integration_tests' : 'apps/$name',
      );
      var code = 0;
      // Capture machine events even when the runner fails, then validate completeness.
      final output = log.openWrite();
      try {
        final result = await executeProcess(
          command,
          cwd: cwd,
          env: {
            'EDAYA_INTEGRATION_TESTS': '1',
            'EDAYA_INTEGRATION_ARTIFACTS': p.join(
              directory.path,
              name,
              'failures',
            ),
          },
          quiet: true,
          timeout: const Duration(minutes: 45),
          onLine: (line) {
            dynamic event;
            try {
              event = jsonDecode(line);
            } catch (_) {
              output.writeln(redact(line));
              return;
            }
            Object? visit(dynamic value) => value is String
                ? redact(value)
                : value is List
                ? value.map(visit).toList()
                : value is Map
                ? value.map((key, item) => MapEntry(key, visit(item)))
                : value;
            output.writeln(jsonEncode(visit(event)));
          },
        );
        code = result.code;
      } catch (error) {
        code = 127;
        output.writeln(redact(error.toString()));
      } finally {
        await output.close();
      }
      writeJson(exitFile.path, code);
      writeJson(metadata.path, {
        'fingerprint': fingerprint,
        'completed': true,
        'completedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
    final report = log.existsSync() && exitFile.existsSync()
        ? evaluate(
            log.readAsLinesSync(),
            jsonDecode(exitFile.readAsStringSync()) as int,
            (registry[name] as List).cast<String>(),
          )
        : <String, dynamic>{
            'ok': false,
            'tests': [],
            'problems': <String>['missing suite artifacts'],
            'routes': null,
          };
    final saved = metadata.existsSync()
        ? jsonFile(metadata.path)
        : <String, dynamic>{};
    final problems = (report['problems'] as List).cast<String>();
    if (saved['completed'] != true ||
        saved['fingerprint'] != fingerprint ||
        fingerprint != sourceFingerprint()) {
      problems.add('missing, incomplete, or stale execution metadata');
    }
    if (features.containsKey(name)) {
      problems.addAll(
        featureProblems(
          features[name] as Map<String, dynamic>,
          (registry[name] as List).cast<String>(),
          (report['routes'] as List?)?.cast<String>(),
        ),
      );
    }
    report['ok'] = problems.isEmpty;
    summaries[name] = report;
    stdout.writeln('$name: ${report['ok'] == true ? 'PASS' : 'FAIL'}');
  }
  final ok = summaries.values.every((row) => row['ok'] == true);
  writeJson(p.join(directory.path, 'summary.json'), {
    'ok': ok,
    'suites': summaries,
  });
  final sanitized = <String, dynamic>{};
  for (final name in ['api', 'guardian', 'teacher']) {
    final row = summaries[name] as Map<String, dynamic>?;
    final tests = (row?['tests'] as List?) ?? [];
    sanitized[name] = {
      'passed': row?['ok'] == true,
      'counts': {
        'total': tests.length,
        'passed': tests.where((test) => test['status'] == 'passed').length,
      },
    };
  }
  writeJson(p.join(root, '.ci-evidence/results.json'), {
    'schemaVersion': 1,
    'role': 'mobile',
    'commit': await run(['git', 'rev-parse', 'HEAD'], quiet: true),
    'backendCommit': checkClient()['backendCommit'],
    'clientChecksum': digest(
      File(p.join(root, '.generated/client.json')).readAsBytesSync(),
    ),
    'lockSha256': digest(File(p.join(root, 'pubspec.lock')).readAsBytesSync()),
    'suites': sanitized,
  });
  if (!ok) throw StateError('Integration verification failed');
}
