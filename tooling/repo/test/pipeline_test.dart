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
        final jobs = caller['jobs'] as YamlMap;
        final live = target == 'production';
        final upload = live ? 'app_store_upload' : 'testflight';
        expect(
          jobs.keys,
          unorderedEquals([
            'qualification',
            'google_play',
            upload,
            if (live) 'app_review',
          ]),
        );
        final qualify = jobs['qualification'];
        expect(qualify['if'], "github.ref == 'refs/heads/$branch'");
        expect(qualify['uses'], './.github/workflows/_qualify_release.yml');
        expect(qualify['with'], {'target': target});
        expect(
          (qualify['secrets'] as YamlMap).keys,
          unorderedEquals([
            'BACKEND_CHECKOUT_TOKEN',
            'ANDROID_SIGNING_BUNDLE',
            'IOS_SIGNING_BUNDLE',
          ]),
        );
        final play = jobs['google_play'];
        expect(play['needs'], 'qualification');
        expect(play['uses'], './.github/workflows/_publish_play.yml');
        expect(play['with']['target'], target);
        expect((play['secrets'] as YamlMap).keys, [
          'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON',
        ]);
        final apple = jobs[upload];
        expect(apple['needs'], 'qualification');
        expect(apple['environment'], target);
        expect(apple['env']['TARGET'], target);
        expect(apple['strategy']['matrix']['app'], ['guardian', 'teacher']);
        expect(apple['strategy']['fail-fast'], isFalse);
        final steps = apple['steps'] as YamlList;
        expect(
          steps.map((s) => s['uses']),
          contains('./.github/actions/upload-ios'),
        );
        expect(
          steps
              .where((s) => s['run'] == 'bundle exec fastlane ios check_review')
              .length,
          live ? 1 : 0,
        );
        if (live) {
          final review = jobs['app_review'];
          expect(review['needs'], upload);
          expect(review['environment'], 'production');
          expect(review['strategy'], apple['strategy']);
          final reviewSteps = review['steps'] as YamlList;
          expect(
            reviewSteps.map((s) => s['run']),
            contains('bundle exec fastlane ios submit'),
          );
          final downloads = reviewSteps.where(
            (s) =>
                s['uses'].toString().startsWith('actions/download-artifact@'),
          );
          expect(
            downloads.map((s) => s['with']['name']),
            unorderedEquals([
              r'prepared-${{ github.run_id }}-${{ github.run_attempt }}',
              r'qualified-${{ github.run_id }}-${{ github.run_attempt }}',
              r'receipts-ios-${{ matrix.app }}-upload-${{ github.run_id }}-${{ github.run_attempt }}',
            ]),
          );
        }
      }
    },
  );
  test(
    'qualification gates every build and integration suite and scopes signing secrets',
    () {
      final branch = workflow('branch_check')['jobs'] as YamlMap;
      expect(branch.keys, unorderedEquals(['preparation', 'quality', 'unit']));
      expect(branch['preparation']['with']['match_backend_branch'], isTrue);
      for (final name in ['pr_validation', '_qualify_release']) {
        final caller = workflow(name);
        final jobs = caller['jobs'] as YamlMap;
        expect(
          jobs.keys,
          unorderedEquals(['preparation', ...stages, 'qualification']),
        );
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
        if (name == '_qualify_release') {
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
          } else {
            expect((job['secrets'] as YamlMap).keys, [
              android ? 'ANDROID_SIGNING_BUNDLE' : 'IOS_SIGNING_BUNDLE',
            ]);
          }
        }
      }
    },
  );
  test('Play commits both apps only after both edits have been prepared', () {
    final jobs = workflow('_publish_play')['jobs'] as YamlMap;
    expect(jobs.keys, unorderedEquals(['prepare', 'publish']));
    expect(jobs['prepare']['needs'], isNull);
    expect(jobs['publish']['needs'], 'prepare');
    for (final id in ['prepare', 'publish']) {
      final job = jobs[id];
      expect(job['strategy']['matrix']['app'], ['guardian', 'teacher']);
      expect(job['strategy']['fail-fast'], isFalse);
      expect(job['environment'], r'${{ inputs.target }}');
      final commands = (job['steps'] as YamlList)
          .map((s) => s['run'])
          .whereType<String>();
      expect(commands, [
        'dart run edaya_repo:play "\$TARGET" ${id == 'prepare' ? 'prepare' : 'commit'}',
      ]);
    }
  });
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
