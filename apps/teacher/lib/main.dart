import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app/prototype_app_root.dart';
import 'config/api_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'mock/mock_store.dart';

@pragma('vm:entry-point')
Future<void> teacherFcmBackgroundHandler(RemoteMessage message) {
  return handleEdayaFcmBackgroundMessage(
    message,
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    notificationConfig: PushNotificationConfigs.teacher,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final demo = await DemoStore.resume(DemoRole.teacher);
  Future<void> prepareLive() async {
    configureEdayaFcm(
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      notificationConfig: PushNotificationConfigs.teacher,
    );
    FirebaseMessaging.onBackgroundMessage(teacherFcmBackgroundHandler);
    if (Firebase.apps.isEmpty)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
  }

  if (demo == null) await prepareLive();
  ApiBaseUrlConfig.configure(
    appDefaultUrl: await ApiConfig.resolveDefaultUrl(),
  );
  await ApiBaseUrlConfig.load();
  await AppSettingsController.preload(prefix: demo?.prefix ?? '');
  Levit.enableAutoLinking();
  await initializeDateFormatting();
  runApp(
    DemoHost(
      role: DemoRole.teacher,
      initial: demo,
      prepareLive: prepareLive,
      builder: (local) =>
          PrototypeAppRoot(store: MockStore(), live: true, demo: local),
    ),
  );
}
