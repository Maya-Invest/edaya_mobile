import 'dart:io';
import 'package:path/path.dart' as p;
import 'runtime.dart';

const checksums = {
  'linux_amd64':
      '8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8',
  'linux_arm64':
      '325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6',
  'darwin_arm64':
      'aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f',
  'darwin_amd64':
      '5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644',
};
Future<void> lintWorkflows() async {
  final arch =
      (await run(['uname', '-m'], quiet: true)) == 'arm64' ||
          (await run(['uname', '-m'], quiet: true)) == 'aarch64'
      ? 'arm64'
      : 'amd64';
  final platform =
      '${Platform.isMacOS
          ? 'darwin'
          : Platform.isLinux
          ? 'linux'
          : 'unsupported'}_$arch';
  final expected = checksums[platform];
  if (expected == null) {
    throw StateError('Unsupported workflow validator platform');
  }
  final directory = Directory(
    p.join(root, '.cache/repo-tools/actionlint-1.7.12-$platform'),
  )..createSync(recursive: true);
  final archive = File(p.join(directory.path, 'archive.tar.gz'));
  if (!archive.existsSync() || digest(archive.readAsBytesSync()) != expected) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client
          .getUrl(
            Uri.parse(
              'https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_$platform.tar.gz',
            ),
          )
          .timeout(const Duration(seconds: 30));
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      if (response.statusCode != 200) {
        throw StateError('Could not download workflow validator');
      }
      final bytes = await response
          .fold<List<int>>([], (all, chunk) => all..addAll(chunk))
          .timeout(const Duration(seconds: 60));
      if (digest(bytes) != expected) {
        throw StateError('Workflow validator checksum mismatch');
      }
      archive.writeAsBytesSync(bytes);
    } finally {
      client.close(force: true);
    }
  }
  await run([
    'tar',
    '-xzf',
    archive.path,
    '-C',
    directory.path,
    'actionlint',
  ], quiet: true);
  final binary = p.join(directory.path, 'actionlint');
  await run(['chmod', '755', binary], quiet: true);
  await run([
    binary,
    '-shellcheck=',
    ...files(
      p.join(root, '.github/workflows'),
    ).where((file) => file.path.endsWith('.yml')).map((file) => file.path),
  ]);
}
