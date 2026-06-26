import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app_session_controller.dart';
import 'home_page.dart';
import 'login_page.dart';

/// Routes between login and home based on session state.
class AuthGate extends LView<AppSessionController> {
  const AuthGate({super.key});

  @override
  Widget buildView(BuildContext context, AppSessionController controller) {
    return LWatch(
      () => controller.isAuthenticated
          ? const HomePage()
          : const LoginPage(),
    );
  }
}
