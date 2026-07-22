import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import '../context/student_context_controller.dart';
import 'account_controller.dart';

class AccountPage extends LScopedView<AccountController> {
  const AccountPage({super.key});

  @override
  AccountController onConfigScope(LevitScope scope) {
    return scope.put(
      () => AccountController(
        scope.find<MockStore>(),
        studentContext: scope.find<StudentContextController>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, AccountController controller) {
    return LWatch(() {
      controller.storeTick.value;
      final store = controller.store;
      final selected = GoRouterState.of(context).uri.path;

      return AdaptiveContent(
        child: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            Text('Compte', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: PrototypeSpacing.md),
            SurfaceCard(
              child: Row(
                children: [
                  PersonAvatar(initials: store.guardianInitials, radius: 28),
                  const SizedBox(width: PrototypeSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.guardianFullName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          MockStore.guardianEmail,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.md),
            SurfaceCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profil de contact'),
                    trailing: const Icon(Icons.chevron_right),
                    selected: selected == '/account/profile',
                    onTap: () => context.go('/account/profile'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Paramètres'),
                    trailing: const Icon(Icons.chevron_right),
                    selected: selected == '/settings',
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xl),
            OutlinedButton(
              onPressed: () {
                controller.signOut();
                context.go('/login');
              },
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
      );
    });
  }
}
