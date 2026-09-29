import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../l10n/l10n_extension.dart';
import 'app_session_controller.dart';
import 'login_page.dart';

class AccountSecurityController extends LevitController
    with LevitReactiveTasksMixin {
  AccountSecurityController(this.auth, this.session);
  final AuthClient auth;
  final AppSessionController session;
  final identifiers = LxVar<List<Map<String, dynamic>>>([]);
  final value = LxVar('');
  final channel = LxVar('email');
  final code = LxVar('');
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
    load();
  }

  Future<void> load() async {
    final security = await auth.authenticatorEnabled();
    if (security.isSuccess) totpEnabled(security.data);

    final result = await auth.identifiers();
    if (result.isSuccess) {
      identifiers(result.data ?? []);
    } else {
      error(result.error?.message ?? '');
    }
  }

  Future<void> link() async {
    await runTask(() async {
      error('');
      final result = challengeSent.value
          ? await auth.verifyIdentifier(code.value.trim())
          : await auth.linkIdentifier(
              value: value.value.trim(),
              channel: channel.value,
              recoveryEligible: recoveryEligible.value,
            );
      if (!result.isSuccess) {
        error(result.error?.message ?? '');
        return;
      }
      if (challengeSent.value) {
        challengeSent(false);
        value('');
        code('');
        await load();
      } else {
        challengeSent(true);
      }
    }, id: 'link');
  }

  Future<void> unlink(String id) async {
    await runTask(() async {
      final result = await auth.unlinkIdentifier(id);
      if (!result.isSuccess) {
        error(result.error?.message ?? '');
        return;
      }
      await session.signOut();
    }, id: 'unlink');
  }
}

class AccountSecurityPage extends LScopedView<AccountSecurityController> {
  const AccountSecurityPage({super.key});
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
      appBar: AppBar(title: Text(context.tr.accountSecurity)),
      body: ListView(
        padding: const EdgeInsets.all(24),
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
            DropdownButtonFormField<String>(
              initialValue: controller.channel.value,
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
            TextFormField(
              onChanged: controller.value.call,
              decoration: InputDecoration(
                labelText: controller.channel.value == 'email'
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
              onChanged: controller.code.call,
              decoration: InputDecoration(labelText: context.tr.otpLabel),
            ),
          FilledButton(
            onPressed: controller.isBusy.value ? null : controller.link,
            child: Text(
              controller.challengeSent.value
                  ? context.tr.verifyCodeButton
                  : context.tr.sendCodeButton,
            ),
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
