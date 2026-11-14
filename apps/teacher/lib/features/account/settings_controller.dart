import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

class SettingsController extends LevitController {
  SettingsController({required AppSettingsController settings})
    : _settings = settings;

  final AppSettingsController _settings;

  AppSettingsController get settings => _settings;
}
