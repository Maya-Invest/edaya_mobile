import 'dart:io';
import 'package:edaya_repo/src/pipeline.dart';
import 'package:edaya_repo/src/integration.dart';
import 'package:edaya_repo/src/runtime.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import '../bin/backend_ref.dart' as backend;

YamlMap workflow(String name) =>
    loadYaml(
          File(p.join(root, '.github/workflows/$name.yml')).readAsStringSync(),
        )
        as YamlMap;

void main() {
  test(
    'match exact backend branches and fall back only to an existing dev',
    () {
      const refs = 'abc\trefs/heads/feature/a\ndef\trefs/heads/dev';
      expect(backend.matchingBranch('feature/a', refs), 'feature/a');
      expect(backend.matchingBranch('feature', refs), 'dev');
      expect(() => backend.matchingBranch('feature', ''), throwsStateError);
    },
  );
  test('all direct prerequisites must succeed', () {
    final jobs = {
      for (final key in ['preparation', ...stages]) key: {'result': 'success'},
    };
    requireSuccessfulJobs(jobs);
    for (final key in jobs.keys) {
      for (final result in ['skipped', 'failure', 'cancelled']) {
        expect(
          () => requireSuccessfulJobs({
            ...jobs,
            key: {'result': result},
          }),
          throwsStateError,
        );
      }
      expect(
        () => requireSuccessfulJobs({...jobs}..remove(key)),
        throwsStateError,
      );
    }
  });
  test(
    'each fixture report must match its assigned suite and pinned inputs',
    () {
      final input = {
        'sourceCommit': 'a',
        'backendCommit': 'b',
        'clientChecksum': 'c',
        'dependencyLockChecksum': 'd',
      };
      final results = {
        'commit': 'a',
        'backendCommit': 'b',
        'clientChecksum': 'c',
        'lockSha256': 'd',
        'suites': {
          'api': {
            'passed': true,
            'counts': {'passed': 1, 'total': 1},
          },
        },
      };
      checkIntegration(results, input, 'api');
      expect(
        () => checkIntegration(results, input, 'guardian_v2'),
        throwsStateError,
      );
      for (final counts in [
        {'passed': 0, 'total': 0},
        {'passed': 1, 'total': 2},
      ]) {
        expect(
          () => checkIntegration(
            {
              ...results,
              'suites': {
                'api': {'passed': true, 'counts': counts},
              },
            },
            input,
            'api',
          ),
          throwsStateError,
        );
      }
      for (final key in results.keys) {
        expect(
          () => checkIntegration({...results}..remove(key), input, 'api'),
          throwsStateError,
        );
      }
    },
  );
  test('stage records bind attempt, target and binary contents', () {
    final files = {
      'bundle.aab': digest([1]),
    };
    final inputs = {'attempt': '1', 'environment': 'staging'};
    final record = {'stage': 'android', 'files': files, 'inputs': inputs};
    validateStage(record, 'android', inputs, files);
    expect(
      () => validateStage(record, 'android', inputs, {
        'bundle.aab': digest([2]),
      }),
      throwsStateError,
    );
    expect(() => validateStage(record, 'ios', inputs, files), throwsStateError);
    expect(
      () =>
          validateStage(record, 'android', {...inputs, 'attempt': '2'}, files),
      throwsStateError,
    );
    expect(
      () => validateStage(record, 'android', {
        ...inputs,
        'environment': 'production',
      }, files),
      throwsStateError,
    );
  });
  test(
    'testing and live releases share one queue and accept only their assigned branch',
    () {
      for (final (name, branch, target) in [
        ('deploy_testing', 'staging', 'staging'),
        ('deploy_live', 'main', 'production'),
      ]) {
        final caller = workflow(name);
        expect(
          caller['on'].keys,
          unorderedEquals(['push', 'workflow_dispatch']),
        );
        expect(caller['on']['push']['branches'], [branch]);
        expect(caller['concurrency'], {
          'group': 'mobile-store-release',
          'queue': 'max',
        });
        final job = caller['jobs']['release'];
        expect(job['if'], "github.ref == 'refs/heads/$branch'");
        expect(job['uses'], './.github/workflows/_release.yml');
        expect(job['with'], {'target': target});
        expect(
          (job['secrets'] as YamlMap).keys,
          unorderedEquals(
            (workflow('_release')['on']['workflow_call']['secrets'] as YamlMap)
                .keys,
          ),
        );
      }
    },
  );
  test(
    'entry points gate publication and scope signing and store credentials',
    () {
      final branch = workflow('branch_check')['jobs'] as YamlMap;
      expect(branch.keys, unorderedEquals(['preparation', 'quality', 'unit']));
      expect(branch['preparation']['with']['match_backend_branch'], isTrue);
      for (final name in ['pr_validation', '_release']) {
        final caller = workflow(name);
        final jobs = caller['jobs'] as YamlMap;
        for (final stage in ['quality', 'unit', ...nativeStages.keys]) {
          expect(jobs[stage]['needs'], 'preparation');
        }
        for (final suite in integrationSuites) {
          final job = jobs['integration_$suite'];
          expect(job['uses'], './.github/workflows/_integration_test.yml');
          expect(job['with']['suite'], suite);
          expect(job['needs'], ['preparation', 'quality', 'unit']);
        }
        expect(jobs['qualification']['if'], 'always()');
        expect(
          jobs['qualification']['needs'],
          unorderedEquals(['preparation', ...stages]),
        );
        if (name == '_release') {
          expect(caller['on'].keys, ['workflow_call']);
          for (final job in jobs.values) {
            expect(job['with']['target'], r'${{ inputs.target }}');
          }
          expect(
            jobs['preparation']['with']['source_ref'],
            r'${{ github.sha }}',
          );
        }
        for (final entry in nativeStages.entries) {
          final build = entry.value;
          final app = build.app;
          final platform = build.platform;
          final android = platform == 'android';
          final job = jobs[entry.key];
          expect(job['uses'], './.github/workflows/_build_$platform.yml');
          expect(job['with']['app'], app);
          if (name == 'pr_validation') {
            expect(job['secrets'], isNull);
            expect(
              jobs.keys.where(
                (id) => jobs[id]['uses'] == './.github/workflows/_deploy.yml',
              ),
              isEmpty,
            );
            continue;
          }
          expect((job['secrets'] as YamlMap).keys, [
            android ? 'ANDROID_SIGNING_BUNDLE' : 'IOS_SIGNING_BUNDLE',
          ]);
          for (final phase
              in android ? ['prepare', 'publish'] : ['upload', 'submit']) {
            final deploy = jobs['${phase}_${platform}_$app'];
            expect(deploy['uses'], './.github/workflows/_deploy.yml');
            expect(deploy['with']['app'], app);
            expect(deploy['with']['platform'], platform);
            expect(deploy['with']['phase'], phase);
            expect((deploy['secrets'] as YamlMap).keys, [
              android
                  ? 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'
                  : 'APP_STORE_CONNECT_API_KEY_JSON',
            ]);
            expect(
              deploy['needs'],
              unorderedEquals([
                'preparation',
                'qualification',
                if (phase == 'publish') ...[
                  'prepare_android_guardian',
                  'prepare_android_teacher',
                ],
                if (phase == 'submit') ...[
                  'upload_ios_guardian',
                  'upload_ios_teacher',
                ],
              ]),
            );
            if (phase == 'submit') {
              expect(deploy['if'], "inputs.target == 'production'");
            }
          }
        }
      }
    },
  );
  test(
    'release stage files and validation evidence are unique to their app and platform',
    () {
      for (final release in [false, true]) {
        final seen = <String>{};
        for (final entry in nativeStages.entries) {
          final files = buildFiles(entry.key, 'staging', release);
          expect(files, isNotEmpty);
          for (final file in files) {
            expect(seen.add(file), isTrue, reason: file);
            expect(file, contains(entry.value.app));
          }
        }
      }
      expect(() => releaseApps('../another-app'), throwsArgumentError);
    },
  );
}
