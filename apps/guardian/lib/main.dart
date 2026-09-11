import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app/guardian_app_root.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureEdayaFcm(
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    notificationConfig: PushNotificationConfigs.guardian,
  );
  registerEdayaFcmBackgroundHandler();
  ApiBaseUrlConfig.configure(
    appDefaultUrl: ApiBaseUrlConfig.stagingUrl,
    appDefaultAuthUrl: ApiBaseUrlConfig.stagingAuthUrl,
  );
  await ApiBaseUrlConfig.load();
  await AppSettingsController.preload();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Levit.enableAutoLinking();
  runApp(GuardianAppRoot());
}
