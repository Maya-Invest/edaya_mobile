import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart' hide LoginPage, PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../config/api_config.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../di/prototype_module.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveLoginPage();
    }
    return const _MockLoginPage();
  }
}

class _MockLoginPage extends StatefulWidget {
  const _MockLoginPage();

  @override
  State<_MockLoginPage> createState() => _MockLoginPageState();
}

class _MockLoginPageState extends State<_MockLoginPage> {
  var _codeSent = false;

  @override
  Widget build(BuildContext context) {
    final store = context.levit.find<MockStore>();

    return _LoginChrome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _codeSent ? 'Vérifiez votre e-mail' : 'Connexion',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: PrototypeSpacing.sm),
          Text(
            _codeSent
                ? 'Saisissez le code envoyé (harness mock).'
                : 'Harness mock — n\'importe quels identifiants fonctionnent.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: PrototypeSpacing.md),
          if (!_codeSent) ...[
            const TextField(
              decoration: InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: PrototypeSpacing.lg),
            FilledButton(
              onPressed: () => setState(() => _codeSent = true),
              child: const Text('Envoyer le code'),
            ),
          ] else ...[
            const TextField(
              decoration: InputDecoration(
                labelText: 'Code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: PrototypeSpacing.lg),
            FilledButton(
              onPressed: () {
                store.signIn();
                context.go('/home');
              },
              child: const Text('Vérifier le code'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveLoginPage extends LScopedView<LoginController> {
  const _LiveLoginPage();

  @override
  LoginController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LoginController(
        authClient: scope.find<AuthClient>(),
        session: scope.find<AppSessionController>(),
        defaultEmail: ApiConfig.devTeacherEmail,
        onSignInSuccess: () => initializeTeacherAuthenticatedContext(scope),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LoginController controller) {
    return _LoginChrome(child: _OtpForm(controller: controller));
  }
}

class _LoginChrome extends StatelessWidget {
  const _LoginChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrototypeColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PrototypeSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EdayaBrandLogo(
                    variant: EdayaLogoVariant.vertical,
                    width: 160,
                  ),
                  const SizedBox(height: PrototypeSpacing.sm),
                  Text(
                    'Espace enseignant',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: PrototypeSpacing.xl),
                  SurfaceCard(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpForm extends StatelessWidget {
  const _OtpForm({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final mode = controller.mode.value;
      return Column(
        key: ValueKey(mode),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            mode == LoginMode.verifyOtp ? 'Vérifiez votre e-mail' : 'Connexion',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: PrototypeSpacing.sm),
          Text(
            mode == LoginMode.verifyOtp
                ? 'Saisissez le code envoyé à ${controller.email.value.trim()}.'
                : 'Un code de connexion vous sera envoyé par e-mail.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: PrototypeSpacing.md),
          if (mode == LoginMode.enterEmail)
            TextFormField(
              initialValue: controller.email.value,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => controller.email(value),
            )
          else
            TextFormField(
              initialValue: controller.otp.value,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(
                labelText: 'Code',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => controller.otp(value),
            ),
          const SizedBox(height: PrototypeSpacing.md),
          LWatch(() {
            final message = controller.errorMessage.value;
            if (message.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: PrototypeSpacing.md),
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }),
          LWatch(
            () => FilledButton(
              onPressed: controller.isBusy.value ? null : controller.submit,
              child: controller.isBusy.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      mode == LoginMode.verifyOtp
                          ? 'Vérifier le code'
                          : 'Envoyer le code',
                    ),
            ),
          ),
          if (mode == LoginMode.verifyOtp) ...[
            const SizedBox(height: PrototypeSpacing.sm),
            TextButton(
              onPressed: controller.isBusy.value ? null : controller.resendOtp,
              child: const Text('Renvoyer le code'),
            ),
            TextButton(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.showEmailEntry,
              child: const Text('Utiliser un autre e-mail'),
            ),
          ],
        ],
      );
    });
  }
}
