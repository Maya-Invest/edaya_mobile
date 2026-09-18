import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart' hide LoginPage;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';

/// Prototype-branded guardian login. Real auth via shared [LoginController];
/// mock harnesses pass [mockStore] instead.
class LoginPage extends LScopedView<LoginController> {
  const LoginPage({
    super.key,
    required this.defaultEmail,
    required this.onSignInSuccess,
    this.mockStore,
  });

  final String defaultEmail;
  final Future<void> Function() onSignInSuccess;
  final MockStore? mockStore;

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
    final isMock = mockStore != null;

    return Scaffold(
      backgroundColor: PrototypeColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PrototypeSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const EdayaBrandLogo(
                    variant: EdayaLogoVariant.vertical,
                    width: 160,
                  ),
                  const SizedBox(height: PrototypeSpacing.xs),
                  Text(
                    'Espace famille',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: PrototypeSpacing.xxl),
                  SurfaceCard(
                    child: isMock
                        ? _MockLogin(
                            defaultEmail: defaultEmail,
                            mockStore: mockStore!,
                          )
                        : _OtpLogin(controller: controller),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockLogin extends StatefulWidget {
  const _MockLogin({required this.defaultEmail, required this.mockStore});

  final String defaultEmail;
  final MockStore mockStore;

  @override
  State<_MockLogin> createState() => _MockLoginState();
}

class _MockLoginState extends State<_MockLogin> {
  var _codeSent = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _codeSent ? 'Vérifiez votre e-mail' : 'Connexion',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PrototypeSpacing.xs),
        Text(
          _codeSent
              ? 'Saisissez le code envoyé à ${widget.defaultEmail}.'
              : 'Accédez aux informations scolaires de vos enfants.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PrototypeSpacing.xl),
        if (!_codeSent) ...[
          TextFormField(
            initialValue: widget.defaultEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          FilledButton(
            onPressed: () => setState(() => _codeSent = true),
            child: const Text('Envoyer le code'),
          ),
        ] else ...[
          const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          FilledButton(
            onPressed: () {
              widget.mockStore.signIn();
              context.go('/home');
            },
            child: const Text('Vérifier le code'),
          ),
        ],
      ],
    );
  }
}

class _OtpLogin extends StatelessWidget {
  const _OtpLogin({required this.controller});

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
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PrototypeSpacing.xs),
          Text(
            mode == LoginMode.verifyOtp
                ? 'Saisissez le code envoyé à ${controller.email.value.trim()}.'
                : 'Accédez aux informations scolaires de vos enfants.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PrototypeSpacing.xl),
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
