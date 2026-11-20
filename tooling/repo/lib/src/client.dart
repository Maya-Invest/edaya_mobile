import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'runtime.dart';

String get generated =>
    p.join(root, 'packages/edaya_api_client/lib/src/generated');
Future<Map<String, dynamic>> acquireClient(
  String target, {
  String? backendRoot,
  String? override,
}) async {
  environment(target);
  final backend = p.absolute(backendRoot ?? p.join(root, '.ci/edaya_backend'));
  if (backendRoot == null) {
    final ref = override ?? backendBranch(target);
    if (!Directory(p.join(backend, '.git')).existsSync()) {
      await run([
        'git',
        'clone',
        '--no-checkout',
        'https://github.com/Maya-Invest/edaya_backend.git',
        backend,
      ], quiet: true);
    }
    await run(['git', 'fetch', 'origin', ref], cwd: backend, quiet: true);
    final sha = commit(
      await run(['git', 'rev-parse', 'FETCH_HEAD'], cwd: backend, quiet: true),
    );
    await run(['git', 'checkout', '--detach', sha], cwd: backend, quiet: true);
  }
  final sha = commit(
    await run(['git', 'rev-parse', 'HEAD'], cwd: backend, quiet: true),
  );
  final expected = Platform.environment['CI_BACKEND_SHA'];
  if (expected != null && sha != commit(expected)) {
    throw StateError('Backend differs from resolved candidate');
  }
  if ((await run(
    ['git', 'status', '--porcelain', '--untracked-files=no'],
    cwd: backend,
    quiet: true,
  )).isNotEmpty) {
    throw StateError('Client acquisition requires a clean backend checkout');
  }
  final spec = p.join(backend, 'tooling/repo/fixtures/openapi.json');
  final generator = p.join(
    root,
    'packages/edaya_api_client/tool/generate_api_bindings.dart',
  );
  final generatorHash = digest(File(generator).readAsBytesSync());
  final runtimeHash = digest(
    utf8.encode(
      jsonEncode({
        for (final file in files(
          p.join(root, 'packages/edaya_api_client/lib'),
        ).where((file) => !file.path.contains('/src/generated/')))
          p.relative(file.path, from: root): digest(file.readAsBytesSync()),
      }),
    ),
  );
  final key = digest(
    utf8.encode(
      jsonEncode([
        sha,
        generatorHash,
        runtimeHash,
        Platform.version,
        digest(File(p.join(root, 'pubspec.lock')).readAsBytesSync()),
      ]),
    ),
  );
  final cache = p.join(root, '.cache/clients', key);
  void restore(Map<String, dynamic> record) {
    if (Directory(generated).existsSync()) {
      Directory(generated).deleteSync(recursive: true);
    }
    for (final file in files(p.join(cache, 'client'))) {
      final destination = File(
        p.join(generated, p.relative(file.path, from: p.join(cache, 'client'))),
      );
      destination.parent.createSync(recursive: true);
      file.copySync(destination.path);
    }
    Directory(p.join(root, '.generated')).createSync(recursive: true);
    File(
      p.join(cache, 'bindings.json'),
    ).copySync(p.join(root, '.generated/client-bindings.json'));
    writeJson(p.join(root, '.generated/client.json'), record);
  }

  if (File(p.join(cache, 'record.json')).existsSync()) {
    final record = jsonFile(p.join(cache, 'record.json'));
    if (record['cacheKey'] == key &&
        record['backendCommit'] == sha &&
        jsonEncode(record['artifacts']) ==
            jsonEncode(hashes(p.join(cache, 'client'))) &&
        record['bindingsChecksum'] ==
            digest(File(p.join(cache, 'bindings.json')).readAsBytesSync())) {
      restore(record);
      return record;
    }
  }
  if (Directory(generated).existsSync()) {
    Directory(generated).deleteSync(recursive: true);
  }
  Directory(p.join(root, '.generated')).createSync(recursive: true);
  await run([
    'dart',
    'run',
    generator,
    '--openapi',
    spec,
    '--bindings',
    p.join(root, '.generated/client-bindings.json'),
    '--output-dir',
    generated,
  ]);
  final record = <String, dynamic>{
    'formatVersion': 1,
    'backendCommit': sha,
    'schemaFingerprint': digest(File(spec).readAsBytesSync()),
    'artifacts': hashes(generated),
    'generator': generatorHash,
    'runtimeFingerprint': runtimeHash,
    'cacheKey': key,
    'bindingsChecksum': digest(
      File(p.join(root, '.generated/client-bindings.json')).readAsBytesSync(),
    ),
  };
  for (final file in files(generated)) {
    final destination = File(
      p.join(cache, 'client', p.relative(file.path, from: generated)),
    );
    destination.parent.createSync(recursive: true);
    file.copySync(destination.path);
  }
  File(
    p.join(root, '.generated/client-bindings.json'),
  ).copySync(p.join(cache, 'bindings.json'));
  writeJson(p.join(cache, 'record.json'), record);
  writeJson(p.join(root, '.generated/client.json'), record);
  return record;
}

Map<String, dynamic> checkClient() {
  final record = jsonFile(p.join(root, '.generated/client.json'));
  commit(record['backendCommit'] as String);
  if (record['formatVersion'] != 1 ||
      jsonEncode(hashes(generated)) != jsonEncode(record['artifacts'])) {
    throw StateError(
      'Prepared client missing or modified; run generate client',
    );
  }
  if (record['generator'] !=
      digest(
        File(
          p.join(
            root,
            'packages/edaya_api_client/tool/generate_api_bindings.dart',
          ),
        ).readAsBytesSync(),
      )) {
    throw StateError('Client generator changed; regenerate client');
  }
  if (record['bindingsChecksum'] !=
      digest(
        File(p.join(root, '.generated/client-bindings.json')).readAsBytesSync(),
      )) {
    throw StateError('Prepared bindings changed');
  }
  final expected = Platform.environment['CI_BACKEND_SHA'];
  if (expected != null && record['backendCommit'] != expected) {
    throw StateError('Prepared client and integration backend differ');
  }
  return record;
}

Future<void> verifyBackend(String backend) async {
  final record = checkClient();
  if (await run(['git', 'rev-parse', 'HEAD'], cwd: backend, quiet: true) !=
          record['backendCommit'] ||
      (await run(
        ['git', 'status', '--porcelain', '--untracked-files=no'],
        cwd: backend,
        quiet: true,
      )).isNotEmpty) {
    throw StateError('Integration backend differs from prepared client');
  }
}
