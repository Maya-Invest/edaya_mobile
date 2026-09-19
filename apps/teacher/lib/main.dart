import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app/prototype_app_root.dart';
import 'firebase_options.dart';
import 'mock/mock_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureEdayaFcm(
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    notificationConfig: PushNotificationConfigs.teacher,
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
  await initializeDateFormatting('fr_FR');
  await initializeDateFormatting('en');
  runApp(PrototypeAppRoot(store: MockStore(), live: true));
}
