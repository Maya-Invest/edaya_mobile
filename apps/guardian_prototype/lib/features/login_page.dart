import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/components/surface_card.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../mock/mock_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.store});

  final MockStore store;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: 'parent@demo.ci');
  final _password = TextEditingController(text: '••••••••');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'E-mail'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: PrototypeSpacing.md),
                        TextField(
                          controller: _password,
                          decoration: const InputDecoration(labelText: 'Mot de passe'),
                          obscureText: true,
                        ),
                        const SizedBox(height: PrototypeSpacing.xl),
                        FilledButton(
                          onPressed: () {
                            widget.store.signIn();
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
