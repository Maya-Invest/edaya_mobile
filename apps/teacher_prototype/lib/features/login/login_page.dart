import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../mock/mock_store.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.levit.find<MockStore>();

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
                  Text(
                    'edaya',
                    textAlign: TextAlign.center,
                    style: PrototypeTypography.brandWordmark(size: 40),
                  ),
                  const SizedBox(height: PrototypeSpacing.sm),
                  Text(
                    'Espace enseignant',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: PrototypeSpacing.xl),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Connexion',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: PrototypeSpacing.sm),
                        Text(
                          'Prototype mock — n\'importe quels identifiants fonctionnent.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: PrototypeSpacing.md),
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'E-mail',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: PrototypeSpacing.md),
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: PrototypeSpacing.lg),
                        FilledButton(
                          onPressed: () {
                            store.signIn();
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
