import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../context/student_context_controller.dart';
import 'account_controller.dart';

class AccountPage extends LScopedView<AccountController> {
  const AccountPage({super.key});

  @override
  AccountController onConfigScope(LevitScope scope) {
    return scope.put(
      () => AccountController(
        session: scope.find<AppSessionController>(),
        studentContext: scope.find<StudentContextController>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, AccountController controller) {
    final selected = GoRouterState.of(context).uri.path;
    final user = controller.session.user.value;

    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text('Compte', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: PrototypeSpacing.md),
          SurfaceCard(
            child: Row(
              children: [
                PersonAvatar(initials: controller.initials, radius: 28),
                const SizedBox(width: PrototypeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        controller.email,
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
            onPressed: () async {
              await controller.signOut();
              if (context.mounted) context.go('/login');
            },
            child: Text(
              user == null ? 'Se déconnecter' : 'Se déconnecter',
            ),
          ),
        ],
      ),
    );
  }
}
