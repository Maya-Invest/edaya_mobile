import 'dart:io';

import 'package:edaya_repo/src/runtime.dart';
import 'package:test/test.dart';

void main() {
  test(
    'release reservations migrate once and advance across branches and retries',
    () async {
      final dir = await Directory.systemTemp.createTemp('store-build-');
      addTearDown(() => dir.delete(recursive: true));
      final gh = File('${dir.path}/gh')
        ..writeAsStringSync(r'''#!/usr/bin/env bash
set -eu
case "$*" in
  *'/git/matching-refs/tags/mobile-store-build/'*)
    jq -Rs 'split("\n") | map(select(length > 0) | {ref: ("refs/tags/mobile-store-build/" + .)})' "$STATE/tags" ;;
  *'/actions/runs?'*)
    echo '{"workflow_runs":[{"id":4,"run_attempt":2,"event":"push","path":".github/workflows/deploy_testing.yml","head_branch":"staging","updated_at":"2026-11-16"},{"id":5,"run_attempt":1,"event":"push","path":".github/workflows/branch_check.yml","head_branch":"dev","updated_at":"2026-11-17"}]}' ;;
  'run download 4 --repo example/mobile --name prepared-4-2 --dir '*)
    mkdir -p "$9/.ci-evidence"
    echo '{"runId":"4","attempt":"2","release":true,"storeBuild":21697882}' > "$9/.ci-evidence/prepared.json" ;;
  *'/git/ref/heads/main --jq .object.sha') echo "$TIP" ;;
  *'--method POST repos/example/mobile/git/refs -f ref=refs/tags/mobile-store-build/'*)
    [[ "$9" == "sha=$GITHUB_SHA" && -z "$REJECT_WRITE" ]] || exit 1
    echo "${7##*/}" >> "$STATE/tags" ;;
  *) echo "Unexpected gh arguments: $*" >&2; exit 1 ;;
esac
''');
      expect((await Process.run('chmod', ['+x', gh.path])).exitCode, 0);
      final tags = File('${dir.path}/tags')..writeAsStringSync('');
      final sha = (await Process.run('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: root)).stdout.toString().trim();
      final output = File('${dir.path}/output');
      Future<ProcessResult> reserve(
        String branch,
        int attempt, {
        bool stale = false,
        bool rejectWrite = false,
      }) {
        output.writeAsStringSync('');
        return Process.run(
          'bash',
          ['.github/scripts/reserve-store-build.sh'],
          workingDirectory: root,
          environment: {
            'PATH': '${dir.path}:${Platform.environment['PATH']}',
            'STATE': dir.path,
            'TIP': stale ? 'superseded' : sha,
            'REJECT_WRITE': rejectWrite ? '1' : '',
            'TARGET': branch == 'main' ? 'production' : 'staging',
            'GITHUB_REF_NAME': branch,
            'GITHUB_REF': 'refs/heads/$branch',
            'GITHUB_SHA': sha,
            'GITHUB_RUN_ATTEMPT': '$attempt',
            'GITHUB_REPOSITORY': 'example/mobile',
            'GITHUB_OUTPUT': output.path,
            'GITHUB_STEP_SUMMARY': '${dir.path}/summary',
          },
        );
      }

      for (final (branch, attempt, expected) in [
        ('staging', 1, 21697883),
        ('main', 1, 21697884),
        ('main', 2, 21697885),
      ]) {
        final result = await reserve(branch, attempt);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(output.readAsLinesSync(), [
          'store_build=$expected',
          'attempt=$attempt',
        ]);
      }
      expect((await reserve('main', 3, stale: true)).exitCode, isNot(0));
      expect(output.readAsStringSync(), isEmpty);
      expect(
        (await reserve('staging', 1, rejectWrite: true)).exitCode,
        isNot(0),
      );
      expect(output.readAsStringSync(), isEmpty);
      expect(tags.readAsLinesSync(), ['21697883', '21697884', '21697885']);
    },
  );
}
