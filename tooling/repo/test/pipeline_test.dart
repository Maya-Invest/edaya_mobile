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
    'entry points gate publication and scope signing and store credentials',
    () {
      final branch = workflow('branche_check')['jobs'] as YamlMap;
      expect(branch.keys, unorderedEquals(['preparation', 'quality', 'unit']));
      expect(branch['preparation']['with']['match_backend_branch'], isTrue);
      for (final name in ['pr_validation', 'deploy']) {
        final caller = workflow(name);
        final jobs = caller['jobs'] as YamlMap;
        for (final stage in ['quality', 'unit', 'android', 'ios']) {
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
        if (name == 'deploy') {
          expect(
            caller['on']['push']['branches'],
            unorderedEquals(['staging', 'main']),
          );
          expect(
            jobs['preparation']['with']['source_ref'],
            r'${{ github.sha }}',
          );
          expect(jobs['deploy']['needs'], contains('qualification'));
          expect(
            (jobs['deploy']['secrets'] as YamlMap).keys,
            unorderedEquals([
              'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON',
              'APP_STORE_CONNECT_API_KEY_JSON',
            ]),
          );
          expect((jobs['android']['secrets'] as YamlMap).keys, [
            'ANDROID_SIGNING_BUNDLE',
          ]);
          expect((jobs['ios']['secrets'] as YamlMap).keys, [
            'IOS_SIGNING_BUNDLE',
          ]);
        } else {
          expect(jobs.containsKey('deploy'), isFalse);
          expect(jobs['android']['secrets'], isNull);
          expect(jobs['ios']['secrets'], isNull);
        }
      }
      final publishers = workflow('_deploy')['jobs'];
      expect(
        publishers['ios']['steps'].singleWhere(
          (s) => s['run'] == 'bundle exec fastlane ios submit',
        )['if'],
        "inputs.target == 'production'",
      );
    },
  );
}
