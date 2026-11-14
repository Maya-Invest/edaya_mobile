import 'dart:convert';
import 'dart:io';
import 'package:edaya_repo/src/android.dart';
import 'package:edaya_repo/src/runtime.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'CI signing preserves checked-in Firebase files and cleans up owned credentials',
    () async {
      for (final mode in [
        'checked-in',
        'absent',
        'wrong-registration',
        'existing-key',
      ]) {
        final fixture = Directory.systemTemp.createTempSync(
          'edaya-signing-test-',
        );
        try {
          Directory(
            p.join(fixture.path, 'apps/guardian'),
          ).createSync(recursive: true);
          File(
            p.join(fixture.path, 'pubspec.yaml'),
          ).writeAsStringSync('name: signing_fixture\n');
          final bundle = <String, dynamic>{
            'keystore': base64Encode([1, 2, 3]),
            'apps': <String, dynamic>{},
          };
          final originals = <String, String>{};
          for (final entry in applicationIds.entries) {
            final directory = Directory(
              p.join(fixture.path, applicationPaths[entry.key]!, 'android/app'),
            )..createSync(recursive: true);
            final firebase = {
              'client': [
                {
                  'client_info': {
                    'mobilesdk_app_id': 'firebase-${entry.key}',
                    'android_client_info': {'package_name': entry.value},
                  },
                },
              ],
            };
            bundle['apps'][entry.key] = {
              'keyAlias': entry.key,
              'keyPassword': 'fixture',
              'storePassword': 'fixture',
              'firebase': firebase,
            };
            if (mode != 'absent') {
              final file = File(p.join(directory.path, 'google-services.json'));
              final content = jsonEncode(firebase).replaceAll(
                'firebase-${entry.key}',
                mode == 'wrong-registration'
                    ? 'wrong-registration'
                    : 'firebase-${entry.key}',
              );
              file.writeAsStringSync(content);
              originals[file.path] = content;
            }
          }
          final keystore = File(
            p.join(fixture.path, 'android-signing/edaya-upload.jks'),
          );
          if (mode == 'existing-key') {
            keystore.parent.createSync(recursive: true);
            keystore.writeAsStringSync('existing-key');
          }
          final script = File(p.join(fixture.path, 'restore_test.dart'))
            ..writeAsStringSync('''
import 'package:edaya_repo/src/android.dart';
Future<void> main() async {
  try { await restoreSigning(); } finally { cleanupSigning(); }
}
''');
          final result = await Process.run(
            Platform.resolvedExecutable,
            [
              '--packages=${p.join(root, '.dart_tool/package_config.json')}',
              script.path,
            ],
            workingDirectory: fixture.path,
            environment: {'ANDROID_SIGNING_BUNDLE': jsonEncode(bundle)},
          );
          expect(
            result.exitCode,
            ['checked-in', 'absent'].contains(mode) ? 0 : isNonZero,
            reason: 'Signing fixture $mode: ${result.stderr}',
          );
          for (final entry in originals.entries) {
            expect(File(entry.key).readAsStringSync(), entry.value);
          }
          expect(keystore.existsSync(), mode == 'existing-key');
          if (mode == 'existing-key') {
            expect(keystore.readAsStringSync(), 'existing-key');
          }
          for (final app in applicationIds.keys) {
            expect(
              File(
                p.join(
                  fixture.path,
                  '${applicationPaths[app]}/android/key.properties',
                ),
              ).existsSync(),
              isFalse,
            );
            if (mode == 'absent') {
              expect(
                File(
                  p.join(
                    fixture.path,
                    '${applicationPaths[app]}/android/app/google-services.json',
                  ),
                ).existsSync(),
                isFalse,
              );
            }
          }
          expect(
            File(p.join(fixture.path, '.ci/signing-owned.json')).existsSync(),
            isFalse,
          );
        } finally {
          fixture.deleteSync(recursive: true);
        }
      }
    },
  );

  test(
    'release app IDs agree across Android, Firebase and Play publishing',
    () {
      expect(applicationIds['guardian'], 'ca.mayainvest.edaya.guardian');
      for (final entry in applicationIds.entries) {
        final appRoot = p.join(root, applicationPaths[entry.key]!);
        final id = entry.value;
        expect(
          id,
          matches(RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$')),
        );
        final gradle = File(
          p.join(appRoot, 'android/app/build.gradle.kts'),
        ).readAsStringSync();
        for (final field in ['applicationId', 'namespace']) {
          expect(
            RegExp('$field = "([^"]+)"').firstMatch(gradle)?.group(1),
            id,
            reason:
                '${entry.key}: $field must match the Play publishing target',
          );
        }
        final activity = File(
          p.join(
            appRoot,
            'android/app/src/main/kotlin',
            id.replaceAll('.', '/'),
            'MainActivity.kt',
          ),
        );
        expect(activity.readAsStringSync(), startsWith('package $id\n'));
        final firebase =
            jsonDecode(
                  File(
                    p.join(appRoot, 'android/app/google-services.json'),
                  ).readAsStringSync(),
                )
                as Map;
        final clients = (firebase['client'] as List).where(
          (client) =>
              client['client_info']['android_client_info']['package_name'] ==
              id,
        );
        expect(
          clients,
          hasLength(1),
          reason: '${entry.key}: exactly one Firebase client must match',
        );
        final firebaseId = clients.single['client_info']['mobilesdk_app_id'];
        final options = File(
          p.join(appRoot, 'lib/firebase_options.dart'),
        ).readAsStringSync();
        final androidOptions = options
            .split('static const FirebaseOptions android = FirebaseOptions(')[1]
            .split(');')[0];
        expect(
          RegExp(r"appId: '([^']+)'").firstMatch(androidOptions)?.group(1),
          firebaseId,
        );
        final metadata = jsonDecode(
          File(p.join(appRoot, 'firebase.json')).readAsStringSync(),
        );
        expect(
          metadata['flutter']['platforms']['android']['default']['appId'],
          firebaseId,
        );
      }
    },
  );
}
