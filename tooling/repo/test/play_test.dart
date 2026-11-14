import 'dart:io';
import 'package:edaya_repo/src/android.dart';
import 'package:edaya_repo/src/play.dart';
import 'package:edaya_repo/src/runtime.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

Map<String, dynamic> track(
  String name,
  int version, {
  String status = 'completed',
}) => {
  'track': name,
  'releases': [
    {
      'name': 'tested',
      'versionCodes': ['$version'],
      'status': status,
      'releaseNotes': [
        {'language': 'en-US', 'text': 'Tested release'},
      ],
    },
  ],
};

class FakePlay {
  final calls = <String>[];
  final bodies = <String, Map<String, dynamic>>{};
  final internal = {
    for (final app in applicationIds.keys) app: track('internal', 123),
  };
  final production = {
    for (final app in applicationIds.keys) app: track('production', 100),
  };
  final recorded = <String>[];
  final bundle = <String, dynamic>{'versionCode': 123, 'sha256': 'hash'};
  bool existingBundle = false;
  bool failTeacherCommit = false;
  PlayPublisher get publisher => PlayPublisher(
    request,
    record: (app, version, status) {
      recorded.add('$app:$version:$status');
    },
  );
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    File? bundle,
  }) async {
    final app = path.startsWith(applicationIds['guardian']!)
        ? 'guardian'
        : 'teacher';
    calls.add('$method $path');
    if (body != null) bodies['$app:$path'] = body;
    if (method == 'DELETE') return {};
    if (path.endsWith('/edits')) return {'id': 'edit'};
    if (method == 'GET' && path.endsWith('/tracks/internal')) {
      return internal[app]!;
    }
    if (method == 'GET' && path.endsWith('/tracks/production')) {
      return production[app]!;
    }
    if (method == 'GET' && path.endsWith('/bundles')) {
      return {
        'bundles': [if (existingBundle) this.bundle],
      };
    }
    if (path.endsWith('/bundles?uploadType=media')) return this.bundle;
    if (method == 'PUT') return body!;
    if (path.endsWith(':commit')) {
      if (app == 'teacher' && failTeacherCommit) {
        throw StateError('simulated failure');
      }
      for (final name in ['internal', 'production']) {
        final update =
            bodies['$app:${path.replaceAll(':commit', '/tracks/$name')}'];
        if (update != null) {
          (name == 'internal' ? internal : production)[app] = update;
        }
      }
      return {'id': 'edit'};
    }
    throw StateError('Unexpected request: $method $path');
  }
}

void main() {
  test(
    'CI version codes increase across runs and retries, and enforce Play limits',
    () {
      Map<String, String> env(int run, int attempt) => {
        'GITHUB_RUN_NUMBER': '$run',
        'GITHUB_RUN_ATTEMPT': '$attempt',
      };
      expect(releaseVersionCode({}), isNull);
      expect(releaseVersionCode(env(10, 1)), 1001001);
      expect(releaseVersionCode(env(10, 2)), 1001002);
      expect(
        releaseVersionCode(env(11, 1)),
        greaterThan(releaseVersionCode(env(10, 99))!),
      );
      expect(() => releaseVersionCode(env(10, 100)), throwsStateError);
      expect(
        () => releaseVersionCode({
          ...env(10, 1),
          'PLAY_VERSION_CODE_BASE': '2100000000',
        }),
        throwsStateError,
      );
      for (final invalid in [
        '0',
        '-1',
        '1.2',
        '1; echo secret',
        '2100000001',
        '',
      ]) {
        expect(() => playVersion(invalid), throwsArgumentError);
      }
    },
  );

  test('publish uploads the signed bundle and commits only internal', () async {
    final fake = FakePlay()..internal['guardian'] = track('internal', 100);
    await fake.publisher.publishInternal(
      'guardian',
      File('bundle.aab'),
      123,
      'hash',
    );
    expect(
      fake.calls.where((c) => c.startsWith('PUT')).single,
      endsWith('/tracks/internal'),
    );
    expect(
      fake.calls.any((c) => c.endsWith('/bundles?uploadType=media')),
      isTrue,
    );
    expect(fake.recorded, ['guardian:123:internal']);
    expect(fake.internal['guardian']!['releases'][0]['versionCodes'], ['123']);
  });

  test('publish retry reuses the exact existing bundle', () async {
    final fake = FakePlay()..existingBundle = true;
    await fake.publisher.publishInternal(
      'guardian',
      File('bundle.aab'),
      123,
      'hash',
    );
    expect(
      fake.calls.any(
        (c) =>
            c.startsWith('PUT') ||
            c.endsWith(':commit') ||
            c.contains('uploadType'),
      ),
      isFalse,
    );
    expect(fake.recorded, ['guardian:123:already-internal']);
  });

  test(
    'upload mismatch or reused version with a different hash cannot commit',
    () async {
      for (final existing in [false, true]) {
        final fake = FakePlay()..existingBundle = existing;
        await expectLater(
          fake.publisher.publishInternal(
            'guardian',
            File('bundle.aab'),
            123,
            'wrong-hash',
          ),
          throwsStateError,
        );
        expect(fake.calls.any((c) => c.endsWith(':commit')), isFalse);
        expect(fake.calls.last, startsWith('DELETE'));
      }
    },
  );

  test('older internal builds cannot replace newer releases', () async {
    final fake = FakePlay();
    await expectLater(
      fake.publisher.publishInternal(
        'guardian',
        File('bundle.aab'),
        122,
        'hash',
      ),
      throwsStateError,
    );
    expect(
      fake.calls.any((c) => c.startsWith('PUT') || c.contains('uploadType')),
      isFalse,
    );
  });

  test(
    'promotion validates both apps then promotes exact versions without uploads',
    () async {
      final fake = FakePlay();
      await fake.publisher.promote({'guardian': 123, 'teacher': 123});
      final firstWrite = fake.calls.indexWhere((c) => c.startsWith('PUT'));
      final lastRead = fake.calls.lastIndexWhere((c) => c.startsWith('GET'));
      expect(firstWrite, greaterThan(lastRead));
      expect(fake.calls.any((c) => c.contains('/bundles')), isFalse);
      expect(fake.recorded, [
        'guardian:123:production',
        'teacher:123:production',
      ]);
      expect(fake.production['teacher']!['releases'][0]['versionCodes'], [
        '123',
      ]);
      expect(
        fake.production['teacher']!['releases'][0]['releaseNotes'][0]['text'],
        'Tested release',
      );
    },
  );

  test('untested or draft second app blocks both production writes', () async {
    for (final release in [
      track('internal', 124),
      track('internal', 123, status: 'draft'),
    ]) {
      final fake = FakePlay()..internal['teacher'] = release;
      await expectLater(
        fake.publisher.promote({'guardian': 123, 'teacher': 123}),
        throwsStateError,
      );
      expect(
        fake.calls.any((c) => c.startsWith('PUT') || c.endsWith(':commit')),
        isFalse,
      );
    }
  });

  test('newer production version blocks downgrade of either app', () async {
    final fake = FakePlay()..production['teacher'] = track('production', 124);
    await expectLater(
      fake.publisher.promote({'guardian': 123, 'teacher': 123}),
      throwsStateError,
    );
    expect(fake.calls.any((c) => c.startsWith('PUT')), isFalse);
  });

  test(
    'retry after partial promotion skips the committed app and finishes the other',
    () async {
      final fake = FakePlay()..failTeacherCommit = true;
      await expectLater(
        fake.publisher.promote({'guardian': 123, 'teacher': 123}),
        throwsStateError,
      );
      expect(fake.recorded, ['guardian:123:production']);
      fake.failTeacherCommit = false;
      fake.calls.clear();
      await fake.publisher.promote({'guardian': 123, 'teacher': 123});
      expect(fake.recorded, [
        'guardian:123:production',
        'guardian:123:already-production',
        'teacher:123:production',
      ]);
      expect(fake.calls.where((c) => c.startsWith('PUT')).length, 1);
    },
  );

  test(
    'both artifact hashes and qualification must pass before publishing',
    () {
      final dir = Directory.systemTemp.createTempSync('play-artifacts-');
      try {
        Directory(p.join(dir.path, 'android')).createSync();
        final manifest = <String, dynamic>{
          'environment': 'production',
          'status': 'qualified',
          'versionCode': 123,
          'tests': {'verification': true, 'integration': true},
          'artifacts': <String, String>{},
        };
        for (final app in applicationIds.keys) {
          final name = 'edaya-$app-production.aab';
          final file = File(p.join(dir.path, 'android', name))
            ..writeAsStringSync(app);
          manifest['artifacts'][name] = digest(file.readAsBytesSync());
        }
        expect(qualifiedBundles(dir.path, manifest).keys, [
          'guardian',
          'teacher',
        ]);
        expect(
          () => qualifiedBundles(dir.path, {
            ...manifest,
            'environment': 'staging',
          }),
          throwsStateError,
        );
        expect(
          () => qualifiedBundles(dir.path, {...manifest, 'status': 'built'}),
          throwsStateError,
        );
        File(
          p.join(dir.path, 'android/edaya-teacher-production.aab'),
        ).writeAsStringSync('tampered');
        expect(() => qualifiedBundles(dir.path, manifest), throwsStateError);
      } finally {
        dir.deleteSync(recursive: true);
      }
    },
  );

  test(
    'production publishing is manual and serialized with internal publishing',
    () {
      final promote =
          loadYaml(
                File(
                  p.join(root, '.github/workflows/promote-google-play.yml'),
                ).readAsStringSync(),
              )
              as YamlMap;
      expect((promote['on'] as YamlMap).keys, ['workflow_dispatch']);
      final job = promote['jobs']['promote'];
      expect(job['if'], "github.ref == 'refs/heads/main'");
      expect(job['environment'], 'google-play-production');
      expect(job['concurrency']['group'], 'google-play-release-production');
      expect(job['concurrency']['cancel-in-progress'], isFalse);
      final deploy =
          loadYaml(
                File(
                  p.join(root, '.github/workflows/_deploy.yml'),
                ).readAsStringSync(),
              )
              as YamlMap;
      final steps = deploy['jobs']['deploy']['steps'] as YamlList;
      final publish = steps.singleWhere(
        (s) => s['run'] == 'dart run edaya_repo:play internal',
      );
      expect(publish['if'], "inputs.target == 'production'");
      expect(
        steps.any((s) => s['run'] == 'dart run edaya_repo:play promote'),
        isFalse,
      );
    },
  );
}
