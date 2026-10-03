import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app/prototype_app_root.dart';
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
  configureEdayaFcm(
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    notificationConfig: PushNotificationConfigs.teacher,
  );
  FirebaseMessaging.onBackgroundMessage(teacherFcmBackgroundHandler);
  ApiBaseUrlConfig.configure(appDefaultUrl: ApiBaseUrlConfig.stagingUrl);
  await ApiBaseUrlConfig.load();
  await AppSettingsController.preload();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Levit.enableAutoLinking();
  await initializeDateFormatting('fr_FR');
  await initializeDateFormatting('en');
  runApp(PrototypeAppRoot(store: MockStore(), live: true));
}
