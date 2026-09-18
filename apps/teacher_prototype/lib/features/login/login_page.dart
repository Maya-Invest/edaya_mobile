import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../mock/mock_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  var _codeSent = false;

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
                          _codeSent ? 'Vérifiez votre e-mail' : 'Connexion',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: PrototypeSpacing.sm),
                        Text(
                          _codeSent
                              ? 'Saisissez le code envoyé (prototype mock).'
                              : 'Prototype mock — n\'importe quels identifiants fonctionnent.',
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
