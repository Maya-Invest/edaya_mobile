import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../l10n/l10n_extension.dart';

import '../../config/developer_settings_config.dart';
import '../../config/dev_api_url_settings.dart';
import 'app_session_controller.dart';
import 'login_controller.dart';

class LoginPage extends LScopedView<LoginController> {
  const LoginPage({
    super.key,
    required this.appTitle,
    required this.subtitle,
    required this.defaultEmail,
    required this.defaultPassword,
    required this.onSignInSuccess,
  });

  final String appTitle;
  final String subtitle;
  final String defaultEmail;
  final String defaultPassword;
  final Future<void> Function() onSignInSuccess;

  @override
  LoginController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LoginController(
        authClient: scope.find<AuthClient>(),
        session: scope.find<AppSessionController>(),
        defaultEmail: defaultEmail,
        defaultPassword: defaultPassword,
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr.signInTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      initialValue: controller.email.value,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: context.tr.emailLabel,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => controller.email(value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: controller.password.value,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: context.tr.passwordLabel,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => controller.password(value),
                    ),
                    const SizedBox(height: 16),
                    LWatch(() {
                      final message = controller.errorMessage.value;
                      if (message.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      );
                    }),
                    LWatch(
                      () => FilledButton(
                        onPressed: controller.isBusy.value
                            ? null
                            : controller.signInWithPassword,
                        child: controller.isBusy.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.tr.signInButton),
                      ),
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
