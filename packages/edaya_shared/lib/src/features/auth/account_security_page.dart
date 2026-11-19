import 'localized_auth_error.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../l10n/l10n_extension.dart';
import 'app_session_controller.dart';
import 'login_page.dart';
import 'otp_delivery_state.dart';
import 'otp_delivery_controls.dart';
import '../../l10n/l10n_lookup.dart';

class AccountSecurityController extends LevitController
    with LevitReactiveTasksMixin {
  AccountSecurityController(this.auth, this.session);
  final AuthClient auth;
  final AppSessionController session;
  final identifiers = LxVar<List<Map<String, dynamic>>>([]);
  final value = LxVar('');
  final channel = LxVar('email');
  String get selectedChannel =>
      delivery.phoneAvailable.value ? channel.value : 'email';
  final code = LxVar('');
  final codeText = TextEditingController();
  late final delivery = OtpDeliveryState(
    auth,
    input: codeText,
    onInputChanged: code.call,
    active: () => challengeSent.value,
    busy: () => isBusy.value,
  );
  final challengeSent = LxVar(false);
  final recoveryEligible = LxVar(false);
  final error = LxVar('');
  final totpEnabled = LxVar<bool?>(null);
  @override
  void onInit() {
    super.onInit();
    autoDispose(identifiers);
    autoDispose(value);
    autoDispose(channel);
    autoDispose(code);
    autoDispose(challengeSent);
    autoDispose(recoveryEligible);
    autoDispose(error);
    autoDispose(totpEnabled);
    delivery.start();
    load();
  }

  @override
  void onClose() {
    delivery.close();
    codeText.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final security = await auth.authenticatorEnabled();
    if (security.isSuccess) totpEnabled(security.data);

    final result = await auth.identifiers();
    if (result.isSuccess) {
      identifiers(result.data ?? []);
    } else {
      error(localizedAuthError(result.error, systemL10n().accountActionFailed));
    }
  }

  void _deliveryError(AuthError? failure) {
    if (failure?.code == 'delivery_unavailable') {
      challengeSent(false);
      code('');
      codeText.clear();
      error(systemL10n().otpSendFailed);
    } else if (failure?.code == 'NETWORK_ERROR') {
      error(systemL10n().emailSendUnconfirmed);
    } else {
      error(localizedAuthError(failure, systemL10n().accountActionFailed));
    }
  }

  Future<void> link() async {
    if (isBusy.value) return;
    if (!challengeSent.value) {
      final identifier = LoginIdentifier.detect(value.value);
      if (identifier?.kind == 'phone' && !delivery.phoneAvailable.value) {
        error(systemL10n().phoneUnavailable);
        return;
      }
      if (identifier == null || identifier.kind != selectedChannel) {
        error(systemL10n().invalidContact);
        return;
      }
      value(identifier.value);
    }
    await runTask(() async {
      error('');
      final result = challengeSent.value
          ? await auth.verifyIdentifier(code.value.trim())
          : await auth.linkIdentifier(
              value: value.value.trim(),
              channel: selectedChannel,
              recoveryEligible: recoveryEligible.value,
              locale: systemL10n().localeName.startsWith('en') ? 'en' : 'fr',
            );
      delivery.refresh();
      if (!result.isSuccess) {
        _deliveryError(result.error);
        return;
      }
      if (challengeSent.value) {
        challengeSent(false);
        value('');
        code('');
        codeText.clear();
        await load();
      } else {
        delivery.refresh();
        challengeSent(true);
      }
    }, id: 'link');
  }

  Future<void> resend({String action = 'resend'}) async {
    if (action == 'retry'
        ? !delivery.retryable.value
        : action == 'sms'
        ? !delivery.canSms
        : !delivery.canResend) {
      return;
    }
    await runTask(() async {
      error('');
      final result = action == 'retry'
          ? await auth.retryOtpRequest()
          : await auth.resendOtp(action: action);
      delivery.refresh();
      if (!result.isSuccess) {
        _deliveryError(result.error);
      } else {
        code('');
        codeText.clear();
      }
    }, id: 'resend-link');
  }

  Future<void> unlink(String id) async {
    await runTask(() async {
      final result = await auth.unlinkIdentifier(id);
      if (!result.isSuccess) {
        error(
          localizedAuthError(result.error, systemL10n().accountActionFailed),
        );
        return;
      }
      await session.signOut();
    }, id: 'unlink');
  }
}

class AccountSecurityPage extends LScopedView<AccountSecurityController> {
  const AccountSecurityPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  AccountSecurityController onConfigScope(LevitScope scope) => scope.put(
    () => AccountSecurityController(
      scope.find<AuthClient>(),
      scope.find<AppSessionController>(),
    ),
  );
  @override
  Widget buildView(BuildContext context, AccountSecurityController controller) {
    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(context.tr.accountSecurity)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          Text(context.tr.recentSignInHint),
          if (controller.error.value.isNotEmpty)
            Text(
              controller.error.value,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final identifier in controller.identifiers.value)
            ListTile(
              title: Text(identifier['value'] as String),
              trailing: IconButton(
                icon: const Icon(Icons.link_off),
                tooltip: context.tr.unlinkIdentifier,
                onPressed: controller.isBusy.value
                    ? null
                    : () async {
                        final confirmed = await showLevitDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(context.tr.unlinkIdentifier),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).cancelButtonLabel,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).okButtonLabel,
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await controller.unlink(identifier['id'] as String);
                        }
                      },
              ),
            ),
          const SizedBox(height: 24),
          Text(
            context.tr.linkIdentifier,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!controller.challengeSent.value) ...[
            if (controller.delivery.phoneAvailable.value)
              DropdownButtonFormField<String>(
                key: const Key('auth-link-channel'),
                initialValue: controller.selectedChannel,
                items: [
                  DropdownMenuItem(
                    value: 'email',
                    child: Text(context.tr.emailLabel),
                  ),
                  if (controller.delivery.phoneAvailable.value)
                    DropdownMenuItem(
                      value: 'phone',
                      child: Text(context.tr.phoneLabel),
                    ),
                ],
                onChanged: controller.isBusy.value
                    ? null
                    : (value) {
                        if (value != null) controller.channel(value);
                      },
              ),
            TextFormField(
              key: const Key('auth-link-contact'),
              onChanged: controller.value.call,
              enabled: !controller.isBusy.value,
              keyboardType: controller.selectedChannel == 'email'
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              decoration: InputDecoration(
                labelText: controller.selectedChannel == 'email'
                    ? context.tr.emailLabel
                    : context.tr.phoneCountryHint,
              ),
            ),
            CheckboxListTile(
              value: controller.recoveryEligible.value,
              onChanged: (value) => controller.recoveryEligible(value ?? false),
              title: Text(context.tr.recoveryEligible),
            ),
          ] else
            TextFormField(
              key: const Key('auth-link-code'),
              controller: controller.codeText,
              enabled: !controller.isBusy.value,
              onChanged: controller.code.call,
              decoration: InputDecoration(
                labelText: context.tr.otpLabel,
                helperText:
                    controller.delivery.isTestAutofilled(controller.code.value)
                    ? context.tr.testCodeAutofilled
                    : null,
                helperMaxLines: 3,
              ),
            ),
          if (!controller.challengeSent.value &&
              controller.delivery.remaining.value > 0)
            Text(
              context.tr.resendCountdown(controller.delivery.remaining.value),
            ),
          FilledButton(
            key: const Key('auth-link-submit'),
            onPressed:
                controller.isBusy.value ||
                    (!controller.challengeSent.value &&
                        controller.delivery.remaining.value > 0) ||
                    (controller.challengeSent.value &&
                        controller.delivery.status.value?.lifecycle !=
                            'pending')
                ? null
                : controller.link,
            child: Text(
              controller.challengeSent.value
                  ? context.tr.verifyCodeButton
                  : context.tr.sendCodeButton,
            ),
          ),
          if (controller.challengeSent.value)
            OtpDeliveryControls(
              state: controller.delivery,
              onResend: () => controller.resend(),
              onSms: () => controller.resend(action: 'sms'),
              onRetry: () => controller.resend(action: 'retry'),
            ),
          const SizedBox(height: 24),
          if (controller.totpEnabled.value == false)
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => LoginPage(
                    appTitle: context.tr.accountSecurity,
                    subtitle: context.tr.authenticatorSetup,
                    defaultEmail: '',
                    startWithEnrollment: true,
                    onSignInSuccess: () async {
                      if (context.mounted) Navigator.of(context).pop();
                      await controller.load();
                    },
                  ),
                ),
              ),
              child: Text(context.tr.enableAuthenticator),
            ),
        ],
      ),
    );
  }
}
