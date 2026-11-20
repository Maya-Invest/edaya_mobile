import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] when auth state changes so redirects run again.
class EdayaRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
