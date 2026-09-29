import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../l10n/l10n_extension.dart';
import 'login_controller.dart';

/// The complete account authentication flow shared by both branded apps.
class PasswordlessLoginForm extends StatelessWidget {
  const PasswordlessLoginForm({
    super.key,
    required this.controller,
    required this.subtitle,
  });
  final LoginController controller;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LWatch(() {
        final mode = controller.mode.value;
        final title = mode == LoginMode.verifyOtp
            ? context.tr.verifyEmailTitle
            : context.tr.signInTitle;
        final description = mode == LoginMode.verifyOtp
            ? context.tr.verificationCodeSent(controller.email.value.trim())
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
            if (mode == LoginMode.saveRecoveryCodes) ...[
              Text(context.tr.saveRecoveryCodes),
              SelectableText(
                controller.recoveryCodes.value.join('\n'),
                key: const Key('auth-recovery-codes'),
              ),
            ] else if (mode == LoginMode.enterEmail) ...[
              DropdownButtonFormField<String>(
                key: const Key('auth-channel'),
                initialValue: controller.channel.value,
                decoration: InputDecoration(
                  labelText: context.tr.deliveryChannel,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'email',
                    child: Text(context.tr.emailLabel),
                  ),
                  const DropdownMenuItem(
                    value: 'telegram',
                    child: Text('Telegram'),
                  ),
                  const DropdownMenuItem(
                    value: 'whatsapp',
                    child: Text('WhatsApp'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) controller.channel(value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('auth-identifier'),
                initialValue: controller.email.value,
                keyboardType: controller.channel.value == 'email'
                    ? TextInputType.emailAddress
                    : TextInputType.phone,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: controller.channel.value == 'email'
                      ? context.tr.emailLabel
                      : context.tr.phoneCountryHint,
                ),
                onChanged: (value) => controller.email(value),
              ),
              const SizedBox(height: 16),
            ] else ...[
              if (mode == LoginMode.enrollTotp) ...[
                Text(context.tr.authenticatorSetup),
                SelectableText(
                  controller.enrollmentSecret.value,
                  key: const Key('auth-enrollment-secret'),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const Key('auth-code'),
                initialValue: controller.otp.value,
                keyboardType: mode == LoginMode.recovery
                    ? TextInputType.text
                    : TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: InputDecoration(
                  labelText: mode == LoginMode.verifyTotp
                      ? context.tr.authenticatorCode
                      : mode == LoginMode.recovery
                      ? context.tr.recoveryCode
                      : context.tr.otpLabel,
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
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      }),
      LWatch(
        () => FilledButton(
          key: const Key('auth-submit'),
          onPressed: controller.isBusy.value ? null : controller.submit,
          child: controller.isBusy.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  controller.mode.value == LoginMode.saveRecoveryCodes
                      ? context.tr.savedRecoveryCodes
                      : controller.mode.value == LoginMode.enterEmail
                      ? context.tr.sendCodeButton
                      : context.tr.verifyCodeButton,
                ),
        ),
      ),
      LWatch(() {
        if (controller.mode.value == LoginMode.verifyTotp) {
          return TextButton(
            key: const Key('auth-use-recovery'),
            onPressed: controller.isBusy.value ? null : controller.useRecovery,
            child: Text(context.tr.useRecoveryCode),
          );
        }
        if (controller.mode.value != LoginMode.verifyOtp) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            const SizedBox(height: 12),
            TextButton(
              key: const Key('auth-resend'),
              onPressed: controller.isBusy.value ? null : controller.resendOtp,
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
    ],
  );
}
