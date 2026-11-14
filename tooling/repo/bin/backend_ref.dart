// Runs before the workspace and private backend checkout exist.
import 'dart:convert';
import 'dart:io';

String matchingBranch(String requested, String remoteHeads) {
  final branches = {
    for (final line in remoteHeads.split('\n'))
      if (line.contains('\t')) line.split('\t').last.trim(),
  };
  for (final name in [requested, 'dev']) {
    if (branches.contains('refs/heads/$name')) return name;
  }
  throw StateError('Neither backend $requested nor fallback dev exists');
}

Future<void> main() async {
  final env = Platform.environment;
  final requested = env['BACKEND_REF']!;
  if (requested.isEmpty ||
      requested.startsWith('-') ||
      requested.contains(RegExp(r'[\r\n]'))) {
    throw ArgumentError('Invalid backend reference');
  }
  var selected = requested;
  if (env['MATCH_BRANCH'] == 'true') {
    final ref = 'refs/heads/$requested';
    if ((await Process.run('git', ['check-ref-format', ref])).exitCode != 0) {
      throw ArgumentError('Invalid backend branch');
    }
    final credentials = base64Encode(
      utf8.encode('x-access-token:${env['BACKEND_CHECKOUT_TOKEN']!}'),
    );
    final result = await Process.run(
      'git',
      [
        'ls-remote',
        '--heads',
        'https://github.com/Maya-Invest/edaya_backend.git',
        ref,
        'refs/heads/dev',
      ],
      environment: {
        'GIT_TERMINAL_PROMPT': '0',
        'GIT_CONFIG_COUNT': '1',
        'GIT_CONFIG_KEY_0': 'http.https://github.com/.extraheader',
        'GIT_CONFIG_VALUE_0': 'Authorization: Basic $credentials',
      },
    );
    if (result.exitCode != 0) throw StateError('Backend branch lookup failed');
    selected = matchingBranch(requested, result.stdout as String);
  }
  File(
    env['GITHUB_OUTPUT']!,
  ).writeAsStringSync('ref=$selected\n', mode: FileMode.append);
  File(env['GITHUB_STEP_SUMMARY']!).writeAsStringSync(
    'Backend requested `$requested`, selected `$selected`.\n',
    mode: FileMode.append,
  );
}
