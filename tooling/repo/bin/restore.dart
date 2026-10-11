// Bootstrap restoration deliberately uses only dart: libraries, before pub get.
import 'dart:convert';
import 'dart:io';
// The bootstrap runs before workspace dependencies and package URI resolution exist.
// ignore: avoid_relative_lib_imports
import '../lib/src/process.dart';

Future<String> command(String executable, List<String> args) async {
  final token = Platform.environment['GITHUB_TOKEN'];
  final result = await executeProcess(
    [executable, ...args],
    quiet: true,
    env: token == null
        ? null
        : {
            'GIT_CONFIG_COUNT': '1',
            'GIT_CONFIG_KEY_0': 'http.https://github.com/.extraheader',
            'GIT_CONFIG_VALUE_0':
                'AUTHORIZATION: basic ${base64Encode(utf8.encode('x-access-token:$token'))}',
          },
  );
  if (result.code != 0) throw StateError('$executable failed');
  return result.output.trim();
}

Future<void> main() async {
  final env = Platform.environment,
      client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  final repository = env['GITHUB_REPOSITORY'],
      id = env['GITHUB_RUN_ID'],
      attempt = env['GITHUB_RUN_ATTEMPT'],
      token = env['GITHUB_TOKEN'];
  if ([
    repository,
    id,
    attempt,
    token,
  ].any((value) => value == null || value.isEmpty)) {
    throw StateError('GitHub run identity required');
  }
  Future<List<int>> get(Uri uri) async {
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 30));
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      if (response.statusCode != 200) {
        throw StateError('Candidate download failed');
      }
      return await response
          .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw StateError('Candidate request failed or timed out');
    }
  }

  final directory = Directory.systemTemp.createTempSync('edaya-qualified-');
  try {
    final data =
        jsonDecode(
              utf8.decode(
                await get(
                  Uri.parse(
                    'https://api.github.com/repos/$repository/actions/runs/$id/artifacts?per_page=100',
                  ),
                ),
              ),
            )
            as Map;
    final matches = (data['artifacts'] as List)
        .where(
          (a) => a['name'] == 'qualified-$id-$attempt' && a['expired'] == false,
        )
        .toList();
    if (matches.length != 1) {
      throw StateError('Expected one qualified artifact');
    }
    final zip = File('${directory.path}/candidate.zip')
      ..writeAsBytesSync(
        await get(Uri.parse(matches.single['archive_download_url'] as String)),
      );
    final paths = (await command('unzip', ['-Z1', zip.path])).split('\n');
    const prefixes = [
      '.release/',
      '.generated/',
      '.ci-evidence/',
      'packages/edaya_api_client/lib/src/generated/',
    ];
    if (paths.any(
      (path) =>
          path.startsWith('/') ||
          path.contains('\\') ||
          path.split('/').contains('..') ||
          !prefixes.any(
            (prefix) =>
                path.startsWith(prefix) ||
                (path.endsWith('/') && prefix.startsWith(path)),
          ),
    )) {
      throw StateError('Unexpected artifact path');
    }
    await command('unzip', ['-q', zip.path, '-d', directory.path]);
    final evidence =
        jsonDecode(
              File(
                '${directory.path}/.ci-evidence/qualification.json',
              ).readAsStringSync(),
            )
            as Map;
    final sha = evidence['sourceCommit'] as String;
    if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(sha) ||
        evidence['checks']['verification'] != true ||
        evidence['checks']['integration'] != true) {
      throw StateError('Invalid qualification');
    }
    await command('git', ['fetch', 'origin', sha]);
    await command('git', ['checkout', '--detach', sha]);
    for (final prefix in prefixes) {
      final source = Directory('${directory.path}/$prefix');
      if (!source.existsSync()) continue;
      for (final file
          in source
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()) {
        final destination = File(
          file.path.substring(directory.path.length + 1),
        );
        destination.parent.createSync(recursive: true);
        file.copySync(destination.path);
      }
    }
    File('${directory.path}/.release/pubspec.lock').copySync('pubspec.lock');
  } finally {
    client.close(force: true);
    directory.deleteSync(recursive: true);
  }
}
