import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../l10n/l10n_extension.dart';
import '../../ui/edaya_brand_logo.dart';

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
    required this.onSignInSuccess,
  });

  final String appTitle;
  final String subtitle;
  final String defaultEmail;
  final Future<void> Function() onSignInSuccess;

  @override
  LoginController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LoginController(
        authClient: scope.find<AuthClient>(),
        session: scope.find<AppSessionController>(),
        defaultEmail: defaultEmail,
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
                    const Center(
                      child: EdayaBrandLogo(
                        variant: EdayaLogoVariant.vertical,
                        width: 112,
                      ),
                    ),
                    const SizedBox(height: 24),
                    LWatch(() {
                      final mode = controller.mode.value;
                      final title = mode == LoginMode.verifyOtp
                          ? context.tr.verifyEmailTitle
                          : context.tr.signInTitle;
                      final description = mode == LoginMode.verifyOtp
                          ? context.tr.verificationCodeSent(
                              controller.email.value.trim(),
                            )
                          : subtitle;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.start,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.start,
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 24),
                    LWatch(() {
                      final mode = controller.mode.value;
                      return Column(
                        key: ValueKey(mode),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (mode == LoginMode.enterEmail) ...[
                            TextFormField(
                              initialValue: controller.email.value,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: InputDecoration(
                                labelText: context.tr.emailLabel,
                              ),
                              onChanged: (value) => controller.email(value),
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            TextFormField(
                              initialValue: controller.otp.value,
                              keyboardType: TextInputType.number,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              decoration: InputDecoration(
                                labelText: context.tr.otpLabel,
                              ),
                              onChanged: (value) => controller.otp(value),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      );
                    }),
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
                            : controller.submit,
                        child: controller.isBusy.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                controller.mode.value == LoginMode.verifyOtp
                                    ? context.tr.verifyCodeButton
                                    : context.tr.sendCodeButton,
                              ),
                      ),
                    ),
                    LWatch(() {
                      if (controller.mode.value != LoginMode.verifyOtp) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: controller.isBusy.value
                                ? null
                                : controller.resendOtp,
                            child: Text(context.tr.resendCodeButton),
                          ),
                          TextButton(
                            onPressed: controller.isBusy.value
                                ? null
                                : controller.showEmailEntry,
                            child: Text(context.tr.useDifferentEmail),
                          ),
                        ],
                      );
                    }),
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
