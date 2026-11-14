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

  Future<void> publish(
    Map<String, File> bundles,
    int version,
    String target,
  ) async {
    final track = switch (target) {
      'staging' => 'internal',
      'production' => 'production',
      _ => throw ArgumentError('Expected staging or production'),
    };
    final edits = <String>[];
    final pending = <String, String>{};
    try {
      // Stage and verify both apps before making either release visible.
      for (final entry in bundles.entries) {
        final app = entry.key;
        final path = await edit(applicationIds[app]!);
        edits.add(path);
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
              bundle: entry.value,
            );
        if (uploaded['versionCode'] != version ||
            uploaded['sha256'] != digest(entry.value.readAsBytesSync())) {
          throw StateError('$app uploaded bundle version/hash mismatch');
        }
        if (releases(current).any(
          (r) => r['status'] == 'completed' && containsVersion(r, version),
        )) {
          record(app, version, 'already-$track');
          continue;
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
        pending[app] = path;
      }
      for (final entry in pending.entries) {
        await request(
          'POST',
          '${entry.value}:commit?changesNotSentForReview=false',
        );
        record(entry.key, version, track);
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
  String target,
) {
  if (manifest['environment'] != target ||
      manifest['apiUrl'] != releaseApiUrl(target) ||
      manifest['status'] != 'qualified' ||
      manifest['tests']?['verification'] != true ||
      manifest['tests']?['integration'] != true) {
    throw StateError('Google Play requires qualified $target bundles');
  }
  playVersion('${manifest['versionCode']}');
  return {
    for (final app in applicationIds.keys)
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
  if (args.length != 1 || !['staging', 'production'].contains(args.single)) {
    throw ArgumentError('Usage: dart run edaya_repo:play staging|production');
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
    final directory = p.join(root, '.release');
    final manifest = jsonFile(p.join(directory, 'manifest.json'));
    final bundles = qualifiedBundles(directory, manifest, mode);
    await publisher.publish(
      bundles,
      playVersion('${manifest['versionCode']}'),
      mode,
    );
  } finally {
    http.client.close(force: true);
  }
}
