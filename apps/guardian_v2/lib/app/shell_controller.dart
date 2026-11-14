import 'package:levit_flutter/levit_flutter.dart';

import 'shell_tabs.dart';

class PrototypeShellController extends LevitController {
  int lastTabIndex = 0;
  String lastHubPath = GuardianShellTabs.hubPaths.first;

  void rememberFromLocation(String path) {
    final tab = GuardianShellTabs.tabIndexFor(path);
    final hub = GuardianShellTabs.hubPathForLocation(path);
    if (tab != null) lastTabIndex = tab;
    if (hub != null) lastHubPath = hub;
  }
}
