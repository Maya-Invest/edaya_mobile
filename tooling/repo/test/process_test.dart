import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:edaya_repo/src/runtime.dart';

void main() {
  test('cancellation terminates the owned subprocess', () async {
    final directory = Directory.systemTemp.createTempSync('edaya-cancel-');
    Process? supervisor;
    try {
      final ready = File(p.join(directory.path, 'ready'));
      final leaked = File(p.join(directory.path, 'leaked'));
      final child = File(p.join(directory.path, 'child.dart'))
        ..writeAsStringSync(
          "import 'dart:io'; import 'dart:async'; void main() { File(${jsonEncode(ready.path)}).writeAsStringSync('ready'); Timer(const Duration(seconds: 2), () { File(${jsonEncode(leaked.path)}).writeAsStringSync('leaked'); }); }",
        );
      final script = File(p.join(directory.path, 'supervisor.dart'))
        ..writeAsStringSync(
          "import 'dart:io'; import '${Uri.file(p.join(root, 'tooling/repo/lib/src/process.dart'))}'; Future<void> main() async { final result = await executeProcess([Platform.resolvedExecutable, ${jsonEncode(child.path)}], quiet: true); exit(result.code); }",
        );
      supervisor = await Process.start(Platform.resolvedExecutable, [
        script.path,
      ]);
      for (var attempt = 0; attempt < 250 && !ready.existsSync(); attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(ready.existsSync(), isTrue);
      supervisor.kill(ProcessSignal.sigterm);
      expect(
        await supervisor.exitCode.timeout(const Duration(seconds: 5)),
        124,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(leaked.existsSync(), isFalse);
    } finally {
      supervisor?.kill(ProcessSignal.sigkill);
      directory.deleteSync(recursive: true);
    }
  });
  test('crashes, timeouts and missing commands fail closed', () async {
    final directory = Directory.systemTemp.createTempSync('edaya-process-');
    try {
      final crash = File(p.join(directory.path, 'crash.dart'))
        ..writeAsStringSync("import 'dart:io'; void main() { exit(7); }");
      await expectLater(
        run([Platform.resolvedExecutable, crash.path], quiet: true),
        throwsStateError,
      );
      final wait = File(p.join(directory.path, 'wait.dart'))
        ..writeAsStringSync(
          "import 'dart:async'; void main() { Timer.periodic(const Duration(seconds: 1), (_) {}); }",
        );
      await expectLater(
        run(
          [Platform.resolvedExecutable, wait.path],
          quiet: true,
          timeout: const Duration(milliseconds: 200),
        ),
        throwsStateError,
      );
      await expectLater(
        run(['edaya-missing-program', 'private-credential'], quiet: true),
        throwsStateError,
      );
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
  test('workflow releases require qualification without an extra switch', () {
    final rootPath = root;
    final qualification = File(
      p.join(rootPath, '.github/workflows/_qualify.yml'),
    ).readAsStringSync();
    expect(qualification, contains('ci qualify'));
    expect(qualification, contains('--backend-root .ci/edaya_backend'));
    for (final target in ['staging', 'production']) {
      final text = File(
        p.join(rootPath, '.github/workflows/deploy-$target.yml'),
      ).readAsStringSync();
      expect(text, contains('needs: qualify'));
      expect(text, contains('cancel-in-progress: false'));
      expect(text, contains('workflow_dispatch:'));
      final jobs = (loadYaml(text) as YamlMap)['jobs'] as YamlMap;
      final deployJob = jobs['deploy'] as YamlMap;
      expect(deployJob['needs'], 'qualify');
      expect(deployJob['if'], isNull);
      expect(deployJob['uses'], './.github/workflows/_deploy.yml');
      final qualifyJob = jobs['qualify'] as YamlMap;
      expect(qualifyJob['uses'], './.github/workflows/_qualify.yml');
      expect(qualifyJob['if'], isNull);
    }
    final deploy = File(
      p.join(rootPath, '.github/workflows/_deploy.yml'),
    ).readAsStringSync();
    expect(deploy, isNot(contains('generate client')));
    expect(deploy, contains('ci signing-cleanup'));
    final deployJob =
        (loadYaml(deploy) as YamlMap)['jobs']['deploy'] as YamlMap;
    expect(deployJob['environment'], r'${{ inputs.target }}');
    expect(deployJob['if'], isNull);
  });
}
