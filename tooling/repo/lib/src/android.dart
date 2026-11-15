import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'runtime.dart';
import 'client.dart';

const applicationIds = {'guardian': 'ca.mayainvest.edaya.guardian', 'teacher': 'ca.mayainvest.edaya.teacher'};

int? releaseVersionCode(Map<String, String> env) {
  if (env['GITHUB_RUN_NUMBER'] == null) return null;
  final run = int.parse(env['EDAYA_RELEASE_SEQUENCE'] ?? env['GITHUB_RUN_NUMBER']!);
  final attempt = int.parse(env['GITHUB_RUN_ATTEMPT']!);
  final base = int.parse(env['PLAY_VERSION_CODE_BASE'] ?? '1000000');
  final code = base + run * 100 + attempt;
  if (run < 1 || attempt < 1 || attempt > 99 || base < 0 || code > 2100000000) {
    throw StateError('Invalid Google Play version code allocation');
  }
  return code;
}

void verifyApkIdentity(String fingerprint, String verification, String applicationId, String badging) {
  final normalized = verification.toLowerCase();
  if (!normalized.contains('certificate sha-256 digest: ${fingerprint.toLowerCase()}') ||
      normalized.contains('android debug') ||
      !badging.contains("package: name='$applicationId'")) {
    throw StateError('APK signing identity or application ID mismatch');
  }
}

Future<void> privateFile(String path, List<int> bytes) async {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  await run(['chmod', '600', path], quiet: true);
}

Future<void> restoreSigning([Iterable<String>? selected]) async {
  final apps = selected ?? applicationIds.keys;
  final raw = Platform.environment['ANDROID_SIGNING_BUNDLE'];
  if (raw == null) return; // Local builds use existing private signing files.
  final Map<String, dynamic> bundle;
  try {
    bundle = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    throw StateError('Invalid signing bundle; contents omitted');
  }
  final signingFiles = [
    p.join(root, 'android-signing/edaya-upload.jks'),
    for (final app in apps) p.join(root, '${applicationPaths[app]}/android/key.properties'),
  ];
  if (signingFiles.any((path) => File(path).existsSync())) {
    throw StateError('Refusing to replace existing private signing files');
  }
  final owned = [
    ...signingFiles,
    for (final app in apps)
      if (!File(p.join(root, '${applicationPaths[app]}/android/app/google-services.json')).existsSync())
        p.join(root, '${applicationPaths[app]}/android/app/google-services.json'),
  ];
  writeJson(p.join(root, '.ci/signing-owned.json'), {'files': owned});
  final keystore = base64Decode(bundle['keystore'] as String);
  if (keystore.isEmpty) throw StateError('Empty keystore');
  await privateFile(p.join(root, 'android-signing/edaya-upload.jks'), keystore);
  for (final app in apps) {
    final data = bundle['apps'][app] as Map<String, dynamic>;
    for (final key in ['keyAlias', 'keyPassword', 'storePassword']) {
      final value = data[key];
      if (value is! String || value.isEmpty || RegExp(r'[\r\n\\]').hasMatch(value)) {
        throw StateError('Invalid signing configuration');
      }
    }
    final firebase = data['firebase'] as Map<String, dynamic>;
    if (!(firebase['client'] as List).any(
      (client) => client['client_info']['android_client_info']['package_name'] == applicationIds[app],
    )) {
      throw StateError('Firebase application ID mismatch');
    }
    await privateFile(
      p.join(root, '${applicationPaths[app]}/android/key.properties'),
      utf8.encode(
        'storeFile=../../../android-signing/edaya-upload.jks\nkeyAlias=${data['keyAlias']}\nkeyPassword=${data['keyPassword']}\nstorePassword=${data['storePassword']}\n',
      ),
    );
    final firebasePath = p.join(root, '${applicationPaths[app]}/android/app/google-services.json');
    if (File(firebasePath).existsSync()) {
      // Firebase configuration is checked in. Keep it, and ensure the signing
      // bundle targets the same Firebase Android registration.
      final suppliedIds = (firebase['client'] as List)
          .where((client) => client['client_info']['android_client_info']['package_name'] == applicationIds[app])
          .map((client) => client['client_info']['mobilesdk_app_id'])
          .toSet();
      final existingClients = (jsonFile(firebasePath)['client'] as List)
          .where((client) => client['client_info']['android_client_info']['package_name'] == applicationIds[app])
          .toList();
      if (existingClients.length != 1 || !suppliedIds.contains(existingClients.single['client_info']['mobilesdk_app_id'])) {
        throw StateError('Checked-in Firebase configuration does not match signing bundle');
      }
    } else {
      await privateFile(firebasePath, utf8.encode(jsonEncode(firebase)));
    }
  }
}

void cleanupSigning() {
  final marker = File(p.join(root, '.ci/signing-owned.json'));
  if (!marker.existsSync()) return;
  final allowed = {
    p.join(root, 'android-signing/edaya-upload.jks'),
    for (final app in applicationIds.keys) ...[
      p.join(root, '${applicationPaths[app]}/android/key.properties'),
      p.join(root, '${applicationPaths[app]}/android/app/google-services.json'),
    ],
  };
  final paths = (jsonFile(marker.path)['files'] as List).cast<String>();
  if (paths.any((path) => !allowed.contains(path))) {
    throw StateError('Invalid signing cleanup ownership');
  }
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
  marker.deleteSync();
}

Future<void> createKeystore() async {
  final keystore = p.join(root, 'android-signing/edaya-upload.jks');
  if (File(keystore).existsSync() ||
      applicationIds.keys.any((app) => File(p.join(root, '${applicationPaths[app]}/android/key.properties')).existsSync())) {
    throw StateError('Signing files already exist; refusing replacement');
  }
  final random = Random.secure();
  final password = Platform.environment['EDAYA_KEYSTORE_STORE_PASSWORD'] ?? base64Encode(List.generate(32, (_) => random.nextInt(256)));
  final keyPassword = Platform.environment['EDAYA_KEYSTORE_KEY_PASSWORD'] ?? password;
  Directory(p.dirname(keystore)).createSync(recursive: true);
  for (final app in applicationIds.keys) {
    await run(
      [
        'keytool',
        '-genkeypair',
        '-keystore',
        keystore,
        '-storetype',
        'JKS',
        '-storepass:env',
        'STORE_PASSWORD',
        '-keypass:env',
        'KEY_PASSWORD',
        '-alias',
        app,
        '-keyalg',
        'RSA',
        '-keysize',
        '2048',
        '-validity',
        '10000',
        '-dname',
        'CN=Edaya $app, OU=Mobile, O=SoftiLab, L=Abidjan, ST=Abidjan, C=CI',
      ],
      env: {'STORE_PASSWORD': password, 'KEY_PASSWORD': keyPassword},
      quiet: true,
    );
    await privateFile(
      p.join(root, '${applicationPaths[app]}/android/key.properties'),
      utf8.encode(
        'storePassword=$password\nkeyPassword=$keyPassword\nkeyAlias=$app\nstoreFile=../../../android-signing/edaya-upload.jks\n',
      ),
    );
  }
  await run(['chmod', '600', keystore], quiet: true);
  stdout.writeln('Keystore created. Passwords are stored only in private key.properties files; back them up securely.');
}

Map<String, String> signingProperties(String content) {
  final properties = <String, String>{};
  for (final line in content.split('\n')) {
    final index = line.indexOf('=');
    if (index > 0 && !line.startsWith('#')) {
      properties[line.substring(0, index)] = line.substring(index + 1);
    }
  }
  for (final key in ['keyAlias', 'keyPassword', 'storePassword', 'storeFile']) {
    if ((properties[key] ?? '').isEmpty) {
      throw StateError('Missing signing configuration');
    }
  }
  if (properties['keyAlias']!.toLowerCase().contains('debug')) {
    throw StateError('Debug signing forbidden');
  }

  return properties;
}

Future<void> androidBuild(String target) async {
  environment(target);
  final selected = Platform.environment['MOBILE_APP'];
  final apps = releaseApps(selected);
  final outputDir = p.join(root, '.release', selected);
  final versionCode = releaseVersionCode(Platform.environment);
  final client = checkClient();
  for (final name in ['manifest.json', 'signatures.json', 'SHA256SUMS']) {
    final stale = File(p.join(outputDir, name));
    if (stale.existsSync()) stale.deleteSync();
  }
  final version = jsonDecode(await run(['flutter', '--version', '--machine'], quiet: true)) as Map;
  if (version['frameworkVersion'] != '3.44.8') {
    throw StateError('Flutter 3.44.8 required');
  }
  final directory = Directory(p.join(outputDir, 'android'));
  if (directory.existsSync()) directory.deleteSync(recursive: true);
  directory.createSync(recursive: true);
  final sdk = Platform.environment['ANDROID_HOME'] ?? Platform.environment['ANDROID_SDK_ROOT'];
  if (sdk == null) throw StateError('Android SDK path required');
  final versions = Directory(p.join(sdk, 'build-tools')).listSync().whereType<Directory>().toList()
    ..sort((a, b) {
      final x = p.basename(a.path).split('.').map((v) => int.tryParse(v) ?? 0).toList(),
          y = p.basename(b.path).split('.').map((v) => int.tryParse(v) ?? 0).toList();
      for (var i = 0; i < min(x.length, y.length); i++) {
        final comparison = x[i].compareTo(y[i]);
        if (comparison != 0) return comparison;
      }
      return x.length.compareTo(y.length);
    });
  final tools = versions.last.path, signatures = <Map<String, dynamic>>[];
  final api = releaseApiUrl(target);
  try {
    await restoreSigning(apps);
    final fingerprints = <String, String>{};
    for (final app in apps) {
      final android = p.join(root, '${applicationPaths[app]}/android');
      final properties = signingProperties(File(p.join(android, 'key.properties')).readAsStringSync());
      final firebase = jsonFile(p.join(android, 'app/google-services.json'));
      if (!(firebase['client'] as List).any(
        (client) => client['client_info']['android_client_info']['package_name'] == applicationIds[app]!,
      )) {
        throw StateError('Firebase application ID mismatch');
      }
      final temporary = Directory.systemTemp.createTempSync('edaya-signature-');
      try {
        final certificate = File(p.join(temporary.path, 'certificate.der'));
        await run(
          [
            'keytool',
            '-exportcert',
            '-alias',
            properties['keyAlias']!,
            '-keystore',
            p.normalize(p.join(android, properties['storeFile']!)),
            '-storepass:env',
            'EDAYA_KEYSTORE_PASSWORD',
            '-file',
            certificate.path,
          ],
          env: {'EDAYA_KEYSTORE_PASSWORD': properties['storePassword']!},
          quiet: true,
        );
        final description = await run(
          ['keytool', '-printcert', '-file', certificate.path],
          quiet: true,
          env: {'JAVA_TOOL_OPTIONS': '-Duser.language=en -Duser.country=US'},
        );
        if (description.toLowerCase().contains('android debug')) {
          throw StateError('Debug signing forbidden');
        }
        fingerprints[app] = digest(certificate.readAsBytesSync());
      } finally {
        temporary.deleteSync(recursive: true);
      }
    }
    for (final app in apps) {
      final cwd = p.join(root, applicationPaths[app]!);
      final fingerprint = fingerprints[app]!;
      final common = [
        '--release',
        '--no-pub',
        if (versionCode != null) '--build-number=$versionCode',
        '--dart-define=API_URL=$api',
        '--dart-define=TEST_OTP_ACCESS=false',
      ];
      await run(['flutter', 'build', 'apk', ...common], cwd: cwd);
      final apk = p.join(cwd, 'build/app/outputs/flutter-apk/app-release.apk');
      final verification = await run([p.join(tools, 'apksigner'), 'verify', '--print-certs', apk], quiet: true);
      final badging = await run([p.join(tools, 'aapt'), 'dump', 'badging', apk], quiet: true);
      verifyApkIdentity(fingerprint, verification, applicationIds[app]!, badging);
      await run(['flutter', 'build', 'appbundle', ...common], cwd: cwd);
      final bundle = p.join(cwd, 'build/app/outputs/bundle/release/app-release.aab');
      final verified = await run(['jarsigner', '-verify', bundle], quiet: true);
      if (!verified.contains('jar verified.')) {
        throw StateError('AAB signature verification failed');
      }
      final info = await run(
        ['keytool', '-printcert', '-jarfile', bundle],
        quiet: true,
        env: {'JAVA_TOOL_OPTIONS': '-Duser.language=en -Duser.country=US'},
      );
      if (!info.toLowerCase().replaceAll(':', '').contains(fingerprint)) {
        throw StateError('AAB certificate mismatch');
      }
      final prefix = p.join(directory.path, 'edaya-$app-$target');
      final signedBundle = File(bundle).copySync('$prefix.aab');
      final output = target == 'staging' ? File(apk).copySync('$prefix.apk') : signedBundle;
      signatures.add({
        'app': app,
        'applicationId': applicationIds[app]!,
        'certificateSha256': fingerprint,
        'bundleSha256': digest(signedBundle.readAsBytesSync()),
        'sha256': digest(output.readAsBytesSync()),
      });
    }
    File(
      p.join(outputDir, 'SHA256SUMS'),
    ).writeAsStringSync('${hashes(directory.path).entries.map((entry) => '${entry.value}  android/${entry.key}').join('\n')}\n');
    writeJson(p.join(outputDir, 'signatures.json'), signatures);
    writeJson(p.join(outputDir, 'manifest.json'), {
      'formatVersion': 1,
      'sourceCommit': commit(await run(['git', 'rev-parse', 'HEAD'], quiet: true)),
      'environment': target,
      'apiUrl': api,
      'versionCode': versionCode,
      'runtime': 'Flutter 3.44.8 / ${Platform.version}',
      'sourceState': (await run(['git', 'status', '--porcelain'], quiet: true)).isEmpty ? 'clean' : 'working-tree',
      'tools': {
        'flutter': version['frameworkVersion'],
        'dart': version['dartSdkVersion'],
        'java': await run(['java', '--version'], quiet: true),
        'androidBuildTools': p.basename(tools),
      },
      'dependencyLockChecksum': digest(File(p.join(root, 'pubspec.lock')).readAsBytesSync()),
      'client': client,
      'artifacts': hashes(directory.path),
      'status': 'built',
    });
  } finally {
    cleanupSigning();
  }
}
