import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../l10n/l10n_extension.dart';
import 'login_controller.dart';
import 'otp_delivery_controls.dart';
import 'terms_acceptance.dart';

/// The complete account authentication flow shared by both branded apps.
class PasswordlessLoginForm extends StatelessWidget {
  const PasswordlessLoginForm({
    super.key,
    required this.controller,
    this.subtitle,
    this.teacherQuickLogin = false,
  });
  final LoginController controller;
  final String? subtitle;
  final bool teacherQuickLogin;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LWatch(() {
        final mode = controller.mode.value;
        final title = mode == LoginMode.verifyOtp
            ? context.tr.verifyContactTitle
            : context.tr.signInTitle;
        final description = mode == LoginMode.teacherCode
            ? context.tr.teacherQuickHint
            : mode == LoginMode.register
            ? context.tr.noEmailAccount
            : mode == LoginMode.verifyOtp
            ? context.tr.verificationContact(controller.email.value.trim())
            : subtitle ??
                  (controller.delivery.phoneAvailable.value
                      ? context.tr.signInContactSubtitle
                      : context.tr.signInEmailSubtitle);
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
              TextFormField(
                key: const Key('auth-identifier'),
                initialValue: controller.email.value,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                enabled: !controller.isBusy.value,
                decoration: InputDecoration(
                  labelText: controller.delivery.phoneAvailable.value
                      ? context.tr.contactLabel
                      : context.tr.emailLabel,
                  helperText:
                      controller.delivery.phoneAvailable.value &&
                          RegExp(
                            r'^[+\d(]',
                          ).hasMatch(controller.email.value.trim()) &&
                          !controller.email.value.contains('@')
                      ? context.tr.phoneCountryHint
                      : null,
                  helperMaxLines: 3,
                ),
                onChanged: controller.setEmail,
              ),
              const SizedBox(height: 12),
              if (teacherQuickLogin)
                TextButton(
                  onPressed: controller.isBusy.value
                      ? null
                      : () {
                          controller.showEmailEntry();
                          controller.mode(LoginMode.teacherCode);
                        },
                  child: Text(context.tr.teacherQuickLogin),
                ),
            ] else if (mode == LoginMode.teacherCode) ...[
              TextFormField(
                controller: controller.otpText,
                maxLength: 8,
                enabled: !controller.isBusy.value,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: context.tr.teacherQuickLabel,
                ),
                onChanged: (value) => controller.otp(value),
              ),
              TextButton(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.showEmailEntry,
                child: Text(context.tr.changeContact),
              ),
            ] else if (mode == LoginMode.register) ...[
              if (!controller.registrationEligible.value)
                Text(context.tr.invitationGuidance),
              TextButton(
                autofocus: !controller.registrationEligible.value,
                onPressed: controller.isBusy.value
                    ? null
                    : () {
                        controller.showEmailEntry();
                        controller.setEmail('');
                      },
                child: Text(context.tr.useAnotherEmail),
              ),
            ] else ...[
              if (mode == LoginMode.enrollTotp) ...[
                Text(context.tr.authenticatorSetup),
                SelectableText(
                  controller.enrollmentSecret.value,
                  key: const Key('auth-enrollment-secret'),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const Key('auth-code'),
                controller: controller.otpText,
                enabled: !controller.isBusy.value,
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
                  helperText:
                      mode == LoginMode.verifyOtp &&
                          controller.delivery.isTestAutofilled(
                            controller.otp.value,
                          )
                      ? context.tr.testCodeAutofilled
                      : null,
                  helperMaxLines: 3,
                ),
                onChanged: (value) => controller.otp(value),
              ),
              const SizedBox(height: 12),
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
          child: Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
      }),
      LWatch(
        () =>
            controller.mode.value == LoginMode.enterEmail ||
                controller.mode.value == LoginMode.teacherCode ||
                (controller.mode.value == LoginMode.register &&
                    controller.registrationEligible.value &&
                    !controller.termsReady)
            ? TermsAcceptance(controller: controller)
            : const SizedBox.shrink(),
      ),
      LWatch(
        () =>
            controller.mode.value == LoginMode.register &&
                !controller.registrationEligible.value
            ? const SizedBox.shrink()
            : FilledButton(
                autofocus: controller.mode.value == LoginMode.register,
                key: const Key('auth-submit'),
                onPressed:
                    controller.isBusy.value ||
                        (controller.mode.value == LoginMode.teacherCode &&
                            controller.otp.value.trim().length != 8) ||
                        ((controller.mode.value == LoginMode.enterEmail ||
                                controller.mode.value ==
                                    LoginMode.teacherCode ||
                                controller.mode.value == LoginMode.register) &&
                            !controller.termsReady) ||
                        (controller.mode.value == LoginMode.enterEmail &&
                            controller.delivery.remaining.value > 0) ||
                        (controller.mode.value == LoginMode.verifyOtp &&
                            controller.delivery.status.value?.lifecycle !=
                                'pending')
                    ? null
                    : controller.submit,
                child: controller.isBusy.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        controller.mode.value == LoginMode.register
                            ? context.tr.createEmailAccount
                            : controller.mode.value ==
                                  LoginMode.saveRecoveryCodes
                            ? context.tr.savedRecoveryCodes
                            : controller.mode.value == LoginMode.enterEmail
                            ? context.tr.sendCodeButton
                            : context.tr.verifyCodeButton,
                      ),
              ),
      ),
      LWatch(() {
        if (controller.mode.value == LoginMode.enterEmail &&
            controller.delivery.remaining.value > 0) {
          return Text(
            context.tr.resendCountdown(controller.delivery.remaining.value),
          );
        }
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
            OtpDeliveryControls(
              state: controller.delivery,
              onResend: () => controller.resendOtp(),
              onSms: () => controller.resendOtp(action: 'sms'),
              onRetry: () => controller.resendOtp(action: 'retry'),
            ),
            TextButton(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.showEmailEntry,
              child: Text(context.tr.changeContact),
            ),
          ],
        );
      }),
    ],
  );
}
