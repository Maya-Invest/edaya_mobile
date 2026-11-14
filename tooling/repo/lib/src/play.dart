import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'android.dart';
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

  Future<void> publishInternal(
    String app,
    File bundle,
    int version,
    String sha,
  ) async {
    final path = await edit(applicationIds[app]!);
    try {
      final internal = await request('GET', '$path/tracks/internal');
      preventDowngrade(internal, version);
      final bundles = await request('GET', '$path/bundles');
      final existing = (bundles['bundles'] as List? ?? [])
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
      if (uploaded['versionCode'] != version || uploaded['sha256'] != sha) {
        throw StateError('$app uploaded bundle version/hash mismatch');
      }
      if (releases(
        internal,
      ).any((r) => r['status'] == 'completed' && containsVersion(r, version))) {
        record(app, version, 'already-internal');
        return;
      }
      await request(
        'PUT',
        '$path/tracks/internal',
        body: {
          'track': 'internal',
          'releases': [
            {
              'name': 'EDAYA $app $version',
              'versionCodes': ['$version'],
              'status': 'completed',
            },
          ],
        },
      );
      await request('POST', '$path:commit');
      record(app, version, 'internal');
    } finally {
      await discard(path);
    }
  }

  Future<void> promote(Map<String, int> versions) async {
    final pending =
        <
          ({String app, int version, String path, Map<String, dynamic> release})
        >[];
    final edits = <String>[];
    try {
      // Validate both selected versions before changing either production track.
      for (final app in applicationIds.keys) {
        final version = versions[app]!;
        final path = await edit(applicationIds[app]!);
        edits.add(path);
        final production = await request('GET', '$path/tracks/production');
        preventDowngrade(production, version);
        if (releases(production).any(
          (r) => r['status'] == 'completed' && containsVersion(r, version),
        )) {
          record(app, version, 'already-production');
          continue;
        }
        final internal = await request('GET', '$path/tracks/internal');
        final tested = releases(internal)
            .where(
              (r) => r['status'] == 'completed' && containsVersion(r, version),
            )
            .firstOrNull;
        if (tested == null) {
          throw StateError(
            '$app version $version is not a completed internal-testing release',
          );
        }
        pending.add((
          app: app,
          version: version,
          path: path,
          release: {
            'name': tested['name'] ?? 'EDAYA $app $version',
            'versionCodes': ['$version'],
            'status': 'completed',
            if (tested['releaseNotes'] != null)
              'releaseNotes': tested['releaseNotes'],
          },
        ));
      }
      for (final item in pending) {
        await request(
          'PUT',
          '${item.path}/tracks/production',
          body: {
            'track': 'production',
            'releases': [item.release],
          },
        );
        await request('POST', '${item.path}:commit');
        record(item.app, item.version, 'production');
      }
    } finally {
      for (final path in edits) {
        await discard(path);
      }
    }
  }
}

Map<String, File> qualifiedBundles(
  String directory,
  Map<String, dynamic> manifest,
) {
  if (manifest['environment'] != 'production' ||
      manifest['status'] != 'qualified' ||
      manifest['tests']?['verification'] != true ||
      manifest['tests']?['integration'] != true) {
    throw StateError('Google Play requires qualified production bundles');
  }
  playVersion('${manifest['versionCode']}');
  return {
    for (final app in applicationIds.keys)
      app: (() {
        final name = 'edaya-$app-production.aab';
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
  if (args.length != 1 || !['internal', 'promote'].contains(args.single)) {
    throw ArgumentError('Usage: dart run edaya_repo:play internal|promote');
  }
  final token = env['PLAY_ACCESS_TOKEN'];
  if (token == null || token.isEmpty) {
    throw StateError('PLAY_ACCESS_TOKEN required');
  }
  final http = PlayHttp(token);
  final results = <Map<String, dynamic>>[];
  final mode = args.single;
  final publisher = PlayPublisher(
    http.request,
    record: (app, version, status) {
      results.add({
        'app': app,
        'applicationId': applicationIds[app],
        'versionCode': version,
        'status': status,
      });
      writeJson(p.join(root, '.release/play-$mode.json'), {
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
    if (mode == 'internal') {
      final directory = p.join(root, '.release');
      final manifest = jsonFile(p.join(directory, 'manifest.json'));
      final bundles = qualifiedBundles(directory, manifest);
      final version = playVersion('${manifest['versionCode']}');
      for (final entry in bundles.entries) {
        await publisher.publishInternal(
          entry.key,
          entry.value,
          version,
          digest(entry.value.readAsBytesSync()),
        );
      }
    } else {
      await publisher.promote({
        for (final app in applicationIds.keys)
          app: playVersion(env['PLAY_${app.toUpperCase()}_VERSION'] ?? ''),
      });
    }
  } finally {
    http.client.close(force: true);
  }
}
