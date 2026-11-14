import 'dart:io';
import 'package:edaya_repo/src/android.dart';
import 'package:edaya_repo/src/play.dart';
import 'package:edaya_repo/src/runtime.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
  final bundle = <String, dynamic>{
    'versionCode': 123,
    'sha256': digest([1, 2, 3]),
  };
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
    if (path.endsWith(':commit?changesNotSentForReview=false')) {
      path = path.split('?').first;
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
      expect(
        releaseVersionCode({...env(1, 1), 'EDAYA_RELEASE_SEQUENCE': '4'}),
        greaterThan(releaseVersionCode(env(3, 99))!),
      );
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

  late Directory dir;
  late Map<String, File> bundles;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('play-release-');
    bundles = {
      for (final app in applicationIds.keys)
        app: File(p.join(dir.path, '$app.aab'))..writeAsBytesSync([1, 2, 3]),
    };
  });
  tearDown(() => dir.deleteSync(recursive: true));

  for (final entry in {
    'staging': 'internal',
    'production': 'production',
  }.entries) {
    test(
      '${entry.key} publishes both qualified AABs to ${entry.value}',
      () async {
        final fake = FakePlay()
          ..internal.updateAll((_, _) => track('internal', 100));
        await fake.publisher.publish(bundles, 123, entry.key);
        expect(
          fake.calls.where((c) => c.startsWith('PUT')),
          everyElement(endsWith('/tracks/${entry.value}')),
        );
        expect(
          fake.calls.where((c) => c.endsWith('uploadType=media')),
          hasLength(2),
        );
        expect(
          fake.calls.where(
            (c) => c.endsWith(':commit?changesNotSentForReview=false'),
          ),
          hasLength(2),
        );
        expect(fake.recorded, [
          'guardian:123:${entry.value}',
          'teacher:123:${entry.value}',
        ]);
      },
    );
  }

  test(
    'bundle hash conflict and newer second app block both commits',
    () async {
      for (final fake in [
        FakePlay()..production['teacher'] = track('production', 124),
        FakePlay()
          ..existingBundle = true
          ..bundle['sha256'] = 'other',
      ]) {
        await expectLater(
          fake.publisher.publish(bundles, 123, 'production'),
          throwsStateError,
        );
        expect(fake.calls.where((c) => c.contains(':commit')), isEmpty);
      }
    },
  );

  test(
    'retry after a partial release verifies the committed bundle and finishes the other app',
    () async {
      final fake = FakePlay()..failTeacherCommit = true;
      await expectLater(
        fake.publisher.publish(bundles, 123, 'production'),
        throwsStateError,
      );
      expect(fake.recorded, ['guardian:123:production']);
      fake.failTeacherCommit = false;
      fake.existingBundle = true;
      fake.calls.clear();
      await fake.publisher.publish(bundles, 123, 'production');
      expect(fake.calls.where((c) => c.endsWith('uploadType=media')), isEmpty);
      expect(fake.calls.where((c) => c.contains(':commit')), hasLength(1));
      expect(fake.recorded, [
        'guardian:123:production',
        'guardian:123:already-production',
        'teacher:123:production',
      ]);
    },
  );

  test('both artifact hashes and signed build status must match', () {
    final dir = Directory.systemTemp.createTempSync('play-artifacts-');
    try {
      Directory(p.join(dir.path, 'android')).createSync();
      final manifest = <String, dynamic>{
        'environment': 'production',
        'apiUrl': releaseApiUrl('production'),
        'status': 'built',
        'versionCode': 123,
        'artifacts': <String, String>{},
      };
      for (final app in applicationIds.keys) {
        final name = 'edaya-$app-production.aab';
        final file = File(p.join(dir.path, 'android', name))
          ..writeAsStringSync(app);
        manifest['artifacts'][name] = digest(file.readAsBytesSync());
      }
      expect(verifiedBundles(dir.path, manifest, 'production').keys, [
        'guardian',
        'teacher',
      ]);
      expect(
        () => verifiedBundles(dir.path, {
          ...manifest,
          'environment': 'staging',
        }, 'production'),
        throwsStateError,
      );
      expect(
        () => verifiedBundles(dir.path, {
          ...manifest,
          'status': 'incomplete',
        }, 'production'),
        throwsStateError,
      );
      File(
        p.join(dir.path, 'android/edaya-teacher-production.aab'),
      ).writeAsStringSync('tampered');
      expect(
        () => verifiedBundles(dir.path, manifest, 'production'),
        throwsStateError,
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
