import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// Thin wrapper so prototype settings can use shared AppSettingsController.
class SettingsController extends LevitController {
  SettingsController({required AppSettingsController settings})
    : _settings = settings;

  final AppSettingsController _settings;

  AppSettingsController get settings => _settings;
}
