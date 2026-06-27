import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] when auth state changes so redirects run again.
class GuardianRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
