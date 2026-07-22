import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/surface_card.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../context/student_context_controller.dart';
import 'login_controller.dart';

class LoginPage extends LScopedView<LoginController> {
  const LoginPage({super.key});

  @override
  LoginController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LoginController(
        studentContext: scope.find<StudentContextController>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LoginController controller) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PrototypeSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  Text('edaya', style: PrototypeTypography.brandWordmark(size: 48)),
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
                        TextField(
                          controller: controller.email,
                          decoration: const InputDecoration(labelText: 'E-mail'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: PrototypeSpacing.md),
                        TextField(
                          controller: controller.password,
                          decoration:
                              const InputDecoration(labelText: 'Mot de passe'),
                          obscureText: true,
                        ),
                        const SizedBox(height: PrototypeSpacing.xl),
                        FilledButton(
                          onPressed: () {
                            controller.signIn();
                            context.go('/home');
                          },
                          child: const Text('Se connecter'),
                        ),
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
