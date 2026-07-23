import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app/prototype_app_root.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureEdayaFcm(
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    notificationConfig: PushNotificationConfigs.guardian,
  );
  registerEdayaFcmBackgroundHandler();
  ApiBaseUrlConfig.configure(
    appDefaultUrl: ApiBaseUrlConfig.defaultForCurrentPlatform,
  );
  await ApiBaseUrlConfig.load();
  await AppSettingsController.preload();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Levit.enableAutoLinking();
  await initializeDateFormatting('fr_FR');
  runApp(const PrototypeAppRoot());
}
