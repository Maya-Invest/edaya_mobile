import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../ui/edaya_brand_logo.dart';

import '../../config/developer_settings_config.dart';
import '../../config/dev_api_url_settings.dart';
import 'app_session_controller.dart';
import 'login_controller.dart';
import 'passwordless_login_form.dart';

class LoginPage extends LScopedView<LoginController> {
  const LoginPage({
    super.key,
    required this.appTitle,
    required this.subtitle,
    required this.defaultEmail,
    this.startWithEnrollment = false,
    required this.onSignInSuccess,
  });

  final String appTitle;
  final String subtitle;
  final String defaultEmail;
  final bool startWithEnrollment;
  final Future<void> Function() onSignInSuccess;

  @override
  LoginController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LoginController(
        authClient: scope.find<AuthClient>(),
        session: scope.find<AppSessionController>(),
        defaultEmail: defaultEmail,
        startWithEnrollment: startWithEnrollment,
        onSignInSuccess: onSignInSuccess,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LoginController controller) {
    return Scaffold(
      appBar: AppBar(title: Text(appTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: EdayaBrandLogo(
                        variant: EdayaLogoVariant.vertical,
                        width: 112,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PasswordlessLoginForm(
                      controller: controller,
                      subtitle: subtitle,
                    ),
                    if (DeveloperSettingsConfig.enabled) ...[
                      const SizedBox(height: 24),
                      const DevApiUrlSettings(compact: true),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
