import 'package:timezone/data/latest.dart' as tzdata;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app/prototype_app_root.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> guardianFcmBackgroundHandler(RemoteMessage message) {
  return handleEdayaFcmBackgroundMessage(
    message,
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    notificationConfig: PushNotificationConfigs.guardian,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final demo = await DemoStore.resume(DemoRole.guardian);
  Future<void> prepareLive() async {
    configureEdayaFcm(
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      notificationConfig: PushNotificationConfigs.guardian,
    );
    FirebaseMessaging.onBackgroundMessage(guardianFcmBackgroundHandler);
    if (Firebase.apps.isEmpty)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
  }

  if (demo == null) await prepareLive();
  ApiBaseUrlConfig.configure(appDefaultUrl: ApiBaseUrlConfig.stagingUrl);
  await ApiBaseUrlConfig.load();
  await AppSettingsController.preload(prefix: demo?.prefix ?? '');
  Levit.enableAutoLinking();
  await initializeDateFormatting();
  runApp(
    DemoHost(
      role: DemoRole.guardian,
      initial: demo,
      prepareLive: prepareLive,
      builder: (local) => PrototypeAppRoot(demo: local),
    ),
  );
}
