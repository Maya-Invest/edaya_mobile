import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app/prototype_app_root.dart';
import 'mock/mock_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiBaseUrlConfig.configure(
    appDefaultUrl: ApiBaseUrlConfig.defaultForCurrentPlatform,
    appDefaultAuthUrl: ApiBaseUrlConfig.defaultAuthForCurrentPlatform,
  );
  await ApiBaseUrlConfig.load();
  await AppSettingsController.preload();
  Levit.enableAutoLinking();
  await initializeDateFormatting('fr_FR');
  runApp(PrototypeAppRoot(store: MockStore(), live: true));
}
