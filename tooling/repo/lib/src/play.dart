import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'android.dart';
import 'pipeline.dart';
import 'runtime.dart';

typedef PlayRequest =
    Future<Map<String, dynamic>> Function(
      String method,
      String path, {
      Map<String, dynamic>? body,
      File? bundle,
    });

int playVersion(String value) {
  final code = int.tryParse(value);
  if (!RegExp(r'^[1-9][0-9]*$').hasMatch(value) ||
      code == null ||
      code > 2100000000) {
    throw ArgumentError('Expected a Google Play version code (1–2100000000)');
  }
  return code;
}

List<Map<String, dynamic>> releases(Map<String, dynamic> track) =>
    (track['releases'] as List? ?? []).cast<Map<String, dynamic>>();

bool containsVersion(Map<String, dynamic> release, int code) =>
    (release['versionCodes'] as List? ?? []).contains('$code');

void preventDowngrade(Map<String, dynamic> track, int code) {
  for (final release in releases(track)) {
    for (final version in release['versionCodes'] as List? ?? []) {
      if (playVersion('$version') > code) {
        throw StateError(
          'Refusing to replace a newer ${track['track']} release',
        );
      }
    }
  }
}

class PlayHttp {
  PlayHttp(this.token);
  final String token;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    File? bundle,
  }) async {
    final prefix = bundle == null ? '' : '/upload';
    final uri = Uri.parse(
      'https://androidpublisher.googleapis.com$prefix/androidpublisher/v3/applications/$path',
    );
    final request = await client
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 30));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (bundle != null) {
      request.headers.contentType = ContentType('application', 'octet-stream');
      request.contentLength = bundle.lengthSync();
      await request
          .addStream(bundle.openRead())
          .timeout(const Duration(minutes: 5));
    } else if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(minutes: 5));
    final text = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(minutes: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Never include credentials, request bodies, or raw server responses.
      throw StateError(
        'Google Play $method $path failed (HTTP ${response.statusCode}). Check API permissions and Play Console publishing status.',
      );
    }
    return text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
  }
}

class PlayPublisher {
  PlayPublisher(this.request, {required this.record});
  final PlayRequest request;
  final void Function(String app, int version, String status) record;

  Future<String> edit(String package) async {
    final result = await request('POST', '$package/edits', body: {});
    final id = result['id'] as String;
    return '$package/edits/${Uri.encodeComponent(id)}';
  }

  Future<void> discard(String edit) async {
    try {
      await request('DELETE', edit);
    } catch (_) {
      // An edit may already have been committed or expired.
    }
  }

  Future<String?> prepare(
    String app,
    File bundle,
    int version,
    String track,
  ) async {
    final path = await edit(applicationIds[app]!);
    try {
      final current = await request('GET', '$path/tracks/$track');
      preventDowngrade(current, version);
      final inventory = await request('GET', '$path/bundles');
      final existing = (inventory['bundles'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .where((item) => item['versionCode'] == version)
          .firstOrNull;
      final uploaded =
          existing ??
          await request(
            'POST',
            '$path/bundles?uploadType=media',
            bundle: bundle,
          );
      if (uploaded['versionCode'] != version ||
          uploaded['sha256'] != digest(bundle.readAsBytesSync())) {
        throw StateError('$app uploaded bundle version/hash mismatch');
      }
      if (releases(
        current,
      ).any((r) => r['status'] == 'completed' && containsVersion(r, version))) {
        await discard(path);
        return null;
      }
      await request(
        'PUT',
        '$path/tracks/$track',
        body: {
          'track': track,
          'releases': [
            {
              'name': 'EDAYA $app $version',
              'versionCodes': ['$version'],
              'status': 'completed',
            },
          ],
        },
      );
      return path;
    } catch (_) {
      await discard(path);
      rethrow;
    }
  }

  Future<void> commitEdit(
    String app,
    String? path,
    int version,
    String track,
  ) async {
    if (path == null) {
      record(app, version, 'already-$track');
      return;
    }
    final prefix = '${applicationIds[app]!}/edits/';
    if (!path.startsWith(prefix) ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(path.substring(prefix.length))) {
      throw StateError('Unexpected Play edit for $app');
    }
    try {
      await request('POST', '$path:commit?changesNotSentForReview=false');
      record(app, version, track);
    } catch (_) {
      await discard(path);
      rethrow;
    }
  }

  Future<void> publish(
    Map<String, File> bundles,
    int version,
    String target,
  ) async {
    final track = playTrack(target);
    final edits = <String, String?>{};
    try {
      for (final app in bundles.keys) {
        edits[app] = await prepare(app, bundles[app]!, version, track);
      }
      for (final app in bundles.keys) {
        await commitEdit(app, edits.remove(app), version, track);
      }
    } finally {
      for (final path in edits.values.whereType<String>()) {
        await discard(path);
      }
    }
  }
}

String playTrack(String target) => switch (target) {
  'staging' => 'internal',
  'production' => 'production',
  _ => throw ArgumentError('Expected staging or production'),
};

Map<String, File> verifiedBundles(
  String directory,
  Map<String, dynamic> manifest,
  String target, {
  String? selectedApp,
}) {
  if (manifest['environment'] != target ||
      manifest['apiUrl'] != releaseApiUrl(target) ||
      manifest['status'] != 'built') {
    throw StateError('Google Play requires signed $target bundles');
  }
  playVersion('${manifest['versionCode']}');
  return {
    for (final app in releaseApps(selectedApp))
      app: (() {
        final name = 'edaya-$app-$target.aab';
        final file = File(p.join(directory, 'android', name));
        if (!file.existsSync() ||
            digest(file.readAsBytesSync()) != manifest['artifacts']?[name]) {
          throw StateError(
            '$app qualified bundle missing or checksum mismatch',
          );
        }
        return file;
      })(),
  };
}

Future<void> runPlay(List<String> args, Map<String, String> env) async {
  if (args.isEmpty ||
      args.length > 2 ||
      !['staging', 'production'].contains(args.first)) {
    throw ArgumentError(
      'Usage: dart run edaya_repo:play staging|production [prepare|commit]',
    );
  }
  final phase = args.elementAtOrNull(1);
  final scope = env['MOBILE_APP'];
  final apps = releaseApps(scope);
  if (phase != null &&
      (!['prepare', 'commit'].contains(phase) || scope == null)) {
    throw ArgumentError('Play prepare and commit require a single mobile app');
  }
  final token = env['PLAY_ACCESS_TOKEN'];
  if (token == null || token.isEmpty) {
    throw StateError('PLAY_ACCESS_TOKEN required');
  }
  final http = PlayHttp(token);
  final results = <Map<String, dynamic>>[];
  final mode = args.first;
  final publisher = PlayPublisher(
    http.request,
    record: (app, version, status) {
      results.add({
        'app': app,
        'applicationId': applicationIds[app],
        'versionCode': version,
        'status': status,
      });
      writeJson(p.join(root, '.release', scope, 'play-$mode.json'), {
        'releases': results,
      });
      final summary = env['GITHUB_STEP_SUMMARY'];
      final message = '$app: version $version → $status';
      stdout.writeln(message);
      if (summary != null) {
        File(summary).writeAsStringSync('- $message\n', mode: FileMode.append);
      }
    },
  );
  try {
    await verifyPublication('android', mode);
    final bundles = <String, File>{};
    final versions = <int>{};
    for (final app in apps) {
      final directory = p.join(root, '.release', app);
      final manifest = jsonFile(p.join(directory, 'manifest.json'));
      bundles.addAll(
        verifiedBundles(directory, manifest, mode, selectedApp: app),
      );
      versions.add(playVersion('${manifest['versionCode']}'));
    }
    final version = versions.single;
    if (phase == null) {
      await publisher.publish(bundles, version, mode);
      return;
    }
    final app = scope!;
    final track = playTrack(mode);
    final planFile = p.join(root, '.release', app, 'play-edit.json');
    final identity = {
      'app': app,
      'track': track,
      'version': version,
      'sha256': digest(bundles[app]!.readAsBytesSync()),
      'runId': env['GITHUB_RUN_ID'],
      'attempt': env['GITHUB_RUN_ATTEMPT'],
      'source': env['GITHUB_SHA'],
    };
    if (phase == 'prepare') {
      final edit = await publisher.prepare(app, bundles[app]!, version, track);
      writeJson(planFile, {'release': identity, 'edit': edit});
    } else {
      final plan = jsonFile(planFile);
      requireEqual(plan['release'], identity, 'prepared Play edit');
      if (!plan.containsKey('edit')) throw StateError('Missing Play edit');
      await publisher.commitEdit(app, plan['edit'] as String?, version, track);
    }
  } finally {
    http.client.close(force: true);
  }
}
