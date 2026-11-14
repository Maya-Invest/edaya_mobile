import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:edaya_repo/src/runtime.dart';
import 'package:edaya_repo/src/client.dart';
import 'package:edaya_repo/src/integration.dart';
import 'package:edaya_repo/src/brand.dart';
import 'package:edaya_repo/src/android.dart';
import 'package:edaya_repo/src/pipeline.dart';
import 'package:edaya_repo/src/tools.dart';
import 'package:edaya_repo/src/smoke.dart';

const commandHelp = '''Usage: dart run edaya_repo:repo <command>
check                       Prepared client and brand integrity
 test unit|tooling|integration [api|guardian_v2|teacher_v2]
 build staging|production   Signed APK/AAB artifacts
 generate client [staging|production] [--ref REF | --backend-root PATH]
 generate brand|gallery|assets|commands|reviewed-brand-baseline
 dev guardian|teacher
 maintenance keystore|fix|design-review|smoke
 ci verify|qualify|integration|validate-integration|workflows|signing-cleanup
''';
Future<void> execute(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    stdout.write(commandHelp);
    return;
  }
  final group = args.first,
      name = args.length > 1 ? args[1] : null,
      rest = args.skip(2).toList();
  if (group == 'ci') {
    if ([
          'verify',
          'workflows',
          'quality',
          'unit',
          'signing-cleanup',
          'integration',
          'validate-integration',
        ].contains(name) &&
        rest.isNotEmpty) {
      throw ArgumentError('Unexpected CI arguments');
    }
    if (['qualify', 'prepare', 'restore-inputs', 'finalize'].contains(name)) {
      if (rest.length != 1) {
        throw ArgumentError('Expected exactly one environment');
      }
      environment(rest.single);
    }
  }
  if (group == 'generate' &&
      !['client', 'brand'].contains(name) &&
      rest.isNotEmpty) {
    throw ArgumentError('Unexpected generation arguments');
  }
  if (group == 'test' &&
      ((name == 'integration' && rest.length > 1) ||
          (name != 'integration' && rest.isNotEmpty))) {
    throw ArgumentError('Unexpected test arguments');
  }
  if (group == 'generate') {
    if (name == 'client') {
      String? reference, backendRoot;
      for (var i = 1; i < rest.length; i += 2) {
        if (i + 1 >= rest.length ||
            rest[i + 1].startsWith('-') ||
            rest[i + 1].contains('\n')) {
          throw ArgumentError('Expected explicit client option value');
        }
        if (rest[i] == '--ref') {
          reference = rest[i + 1];
        } else if (rest[i] == '--backend-root') {
          backendRoot = rest[i + 1];
        } else {
          throw ArgumentError('Expected --ref or --backend-root');
        }
      }
      if (reference != null &&
          (backendRoot != null || Platform.environment['CI'] == 'true')) {
        throw ArgumentError(
          'Use an explicit local reference or the manual validation workflow',
        );
      }
      await acquireClient(
        rest.firstOrNull ?? 'staging',
        backendRoot: backendRoot,
        override: reference,
      );
      return;
    }
    if (name == 'reviewed-brand-baseline') {
      brandCheck(recordReviewedBaseline: true);
      return;
    }
    if (name == 'brand') {
      if (rest.isNotEmpty) {
        if (rest.length != 2 || rest.first != '--sync-from') {
          throw ArgumentError('Expected brand [--sync-from PATH]');
        }
        tokenDart(jsonFile(p.absolute(rest.last)));
        File(p.absolute(rest.last)).copySync(p.join(design, 'tokens.json'));
      }
      brandTokens();
      return;
    }
    if (name == 'gallery') {
      await brandGallery();
      return;
    }
    if (name == 'assets') {
      await run([
        'flutter',
        'test',
        '--no-pub',
        'tool/brand_assets.dart',
      ], cwd: p.join(root, 'tooling/repo'));
      return;
    }
    if (name == 'commands') {
      File(
        p.join(root, 'tooling/repo/commands.txt'),
      ).writeAsStringSync(commandHelp);
      commandDocs(write: true);
      return;
    }
  }
  if (group == 'check' && name == null) {
    commandDocs();
    checkClient();
    brandCheck();
    return;
  }
  if (group == 'test') {
    if (name == 'tooling') {
      await run(['dart', 'test'], cwd: p.join(root, 'tooling/repo'));
      return;
    }
    if (name == 'unit') {
      await run(['dart', 'run', 'melos', 'run', 'test']);
      return;
    }
    if (name == 'integration') {
      await integration(suite: rest.firstOrNull);
      return;
    }
  }
  if (group == 'build' && name != null && rest.isEmpty) {
    await androidBuild(name);
    return;
  }
  if (group == 'dev' && ['guardian', 'teacher'].contains(name)) {
    checkClient();
    await run(
      ['flutter', 'run', '--no-pub'],
      cwd: p.join(root, applicationPaths[name]!),
      timeout: null,
    );
    return;
  }
  if (group == 'maintenance') {
    if (name == 'keystore') {
      await createKeystore();
      return;
    }
    if (name == 'fix') {
      for (final dir in ['lib', 'test']) {
        if (Directory(dir).existsSync()) {
          await run([
            'dart',
            'fix',
            '--apply',
            dir,
          ], cwd: Directory.current.path);
        }
      }
      return;
    }
    if (name == 'smoke') {
      await stagingSmoke(validateRunner: rest.contains('--validate-runner'));
      return;
    }
    if (name == 'design-review' &&
        ['guardian', 'teacher'].contains(rest.firstOrNull)) {
      final app = rest.first;
      await run(
        [
          'flutter',
          'test',
          '--no-pub',
          'test/integration/${app}_design_review_test.dart',
          '--tags',
          'design-review',
          '--concurrency=1',
        ],
        cwd: p.join(root, applicationPaths[app]!),
        env: {
          'EDAYA_DESIGN_REVIEW_LOCALE':
              Platform.environment['EDAYA_DESIGN_REVIEW_LOCALE'] ?? 'fr',
          'EDAYA_DESIGN_REVIEW_A11Y':
              Platform.environment['EDAYA_DESIGN_REVIEW_A11Y'] ?? '1',
          'EDAYA_DESIGN_REVIEW_STRICT':
              Platform.environment['EDAYA_DESIGN_REVIEW_STRICT'] ?? '1',
        },
      );
      return;
    }
  }
  if (group == 'ci') {
    if (name == 'client-key') {
      if (rest.length != 1) {
        throw ArgumentError('Expected one resolved backend checkout');
      }
      final backend = p.absolute(rest.single);
      final runtime = {
        for (final file
            in files(p.join(root, 'packages/edaya_api_client')).where(
              (file) =>
                  !file.path.contains('/src/generated/') &&
                  !file.path.contains('/.dart_tool/') &&
                  !file.path.contains('/build/') &&
                  !file.path.contains('/spec/'),
            ))
          p.relative(file.path, from: root): digest(file.readAsBytesSync()),
      };
      final key = digest(
        utf8.encode(
          jsonEncode([
            commit(
              await run(
                ['git', 'rev-parse', 'HEAD'],
                cwd: backend,
                quiet: true,
              ),
            ),
            Platform.version,
            runtime,
            hashes(p.join(root, 'tooling/repo/lib')),
            digest(File(p.join(root, 'pubspec.lock')).readAsBytesSync()),
            digest(File(p.join(backend, 'bun.lock')).readAsBytesSync()),
          ]),
        ),
      );
      final output = Platform.environment['GITHUB_OUTPUT'];
      if (output != null) {
        File(
          output,
        ).writeAsStringSync('client_key=$key\n', mode: FileMode.append);
      }
      return;
    }
    if (name == 'prepare') return prepareInputs(rest.single);
    if (name == 'restore-inputs') {
      await verifyPrepared(rest.single);
      return;
    }
    if (name == 'record-stage') return recordStage(rest.first, rest.last);
    if (name == 'finalize') return finalize(rest.single);
    if (name == 'verify-publication') {
      return verifyPublication(rest.first, rest.last);
    }
    if (name == 'native') return validationBuild(rest.first, rest.last);
    if (name == 'signing-cleanup') {
      cleanupSigning();
      return;
    }
    if (name == 'workflows') {
      await lintWorkflows();
      return;
    }
    if (name == 'quality') {
      await execute(['check']);
      await lintWorkflows();
      await run(['dart', 'analyze'], cwd: p.join(root, 'tooling/repo'));
      await run(['dart', 'analyze', 'packages/edaya_api_client/tool']);
      await run(['dart', 'run', 'melos', 'run', 'analyze']);
      await stagingSmoke(validateRunner: true);
      return;
    }
    if (name == 'unit') {
      await execute(['test', 'tooling']);
      await execute(['test', 'unit']);
      await run([
        'bundle',
        'exec',
        'ruby',
        'test/release_test.rb',
      ], cwd: p.join(root, 'tooling/apple'));
      return;
    }
    if (name == 'verify') {
      await execute(['ci', 'quality']);
      await execute(['ci', 'unit']);
      return;
    }
    if (name == 'validate-integration') {
      await integration(validateOnly: true);
      return;
    }
    if (name == 'integration') {
      checkClient();
      final backend = p.absolute(
        Platform.environment['BACKEND_ROOT'] ??
            p.join(root, '.ci/edaya_backend'),
      );
      await verifyBackend(backend);
      await run([
        'bun',
        'install',
        '--frozen-lockfile',
        '--ignore-scripts',
      ], cwd: backend);
      await run(
        [
          'bun',
          '--no-env-file',
          'tooling/repo/ops/main.ts',
          'ci',
          'fixture',
          root,
          '--',
          'dart',
          'run',
          'edaya_repo:repo',
          'test',
          'integration',
        ],
        cwd: backend,
        env: {'EDAYA_FIXTURE_SEED': 'true'},
        timeout: const Duration(minutes: 100),
      );
      return;
    }
    if (name == 'qualify') {
      final evidence = <String, dynamic>{
        'environment': rest.single,
        'dependencyLockChecksum': digest(
          File(p.join(root, 'pubspec.lock')).readAsBytesSync(),
        ),
        'sourceCommit': commit(
          await run(['git', 'rev-parse', 'HEAD'], quiet: true),
        ),
        'client': checkClient(),
        'checks': <String, bool>{'verification': false, 'integration': false},
      };
      final checks = evidence['checks'] as Map<String, bool>;
      writeJson(p.join(root, '.ci-evidence/qualification.json'), evidence);
      try {
        await execute(['ci', 'verify']);
        checks['verification'] = true;
        await execute(['ci', 'integration']);
        checks['integration'] = true;
      } finally {
        writeJson(p.join(root, '.ci-evidence/qualification.json'), evidence);
      }
      return;
    }
  }
  throw ArgumentError('Unknown command.\n$commandHelp');
}

void commandDocs({bool write = false}) {
  final file = File(p.join(root, 'docs/reference/repo-cli.md'));
  final text = file.readAsStringSync();
  const start = '<!-- repo-commands:start -->',
      end = '<!-- repo-commands:end -->';
  final from = text.indexOf(start), to = text.indexOf(end);
  if (from < 0 || to < from) {
    throw StateError('Command documentation markers are missing');
  }
  final expected =
      '${text.substring(0, from + start.length)}\n\n```text\n${commandHelp.trimRight()}\n```\n\n${text.substring(to)}';
  if (write) {
    file.writeAsStringSync(expected);
  } else if (text != expected) {
    throw StateError('Command documentation drift; run generate commands');
  }
}

Future<void> main(List<String> args) async {
  try {
    await execute(args);
  } catch (error) {
    stderr.writeln(redact(error.toString()));
    exitCode = 1;
  }
}
