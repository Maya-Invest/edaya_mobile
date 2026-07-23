import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart' hide LoginPage;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../mock/mock_store.dart';

/// Prototype-branded guardian login. Real auth via shared [LoginController];
/// mock harnesses pass [mockStore] instead.
class LoginPage extends LScopedView<LoginController> {
  const LoginPage({
    super.key,
    required this.defaultEmail,
    required this.defaultPassword,
    required this.onSignInSuccess,
    this.mockStore,
  });

  final String defaultEmail;
  final String defaultPassword;
  final Future<void> Function() onSignInSuccess;
  final MockStore? mockStore;

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
                  Text(
                    'edaya',
                    style: PrototypeTypography.brandWordmark(size: 40),
                  ),
                  const SizedBox(height: PrototypeSpacing.xs),
                  Text(
                    'Espace famille',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: PrototypeSpacing.xxl),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Connexion',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: PrototypeSpacing.xs),
                        Text(
                          'Accédez aux informations scolaires de vos enfants.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: PrototypeSpacing.xl),
                        if (isMock) ...[
                          TextFormField(
                            initialValue: defaultEmail,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: PrototypeSpacing.md),
                          TextFormField(
                            initialValue: defaultPassword,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Mot de passe',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: PrototypeSpacing.xl),
                          FilledButton(
                            onPressed: () {
                              mockStore!.signIn();
                              context.go('/home');
                            },
                            child: const Text('Se connecter'),
                          ),
                        ] else ...[
                          TextFormField(
                            initialValue: controller.email.value,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => controller.email(value),
                          ),
                          const SizedBox(height: PrototypeSpacing.md),
                          TextFormField(
                            initialValue: controller.password.value,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: 'Mot de passe',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => controller.password(value),
                          ),
                          const SizedBox(height: PrototypeSpacing.md),
                          LWatch(() {
                            final message = controller.errorMessage.value;
                            if (message.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: PrototypeSpacing.md,
                              ),
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
                                  : const Text('Se connecter'),
                            ),
                          ),
                        ],
                      ],
                    ),
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
