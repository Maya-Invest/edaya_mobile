import 'package:edaya_config/edaya_config.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app/teacher_app_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiBaseUrlConfig.load();
  Levit.enableAutoLinking();
  runApp(const TeacherAppRoot());
}
