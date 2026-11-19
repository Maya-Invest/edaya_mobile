import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/shell_tabs.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'account_controller.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveAccountPage();
    }
    return const _MockAccountPage();
  }
}

class _MockAccountPage extends LScopedView<StoreBoundController> {
  const _MockAccountPage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final selected = GoRouterState.of(context).uri.path;
    final hubPath = GuardianShellScope.maybeOf(context)?.hubPath ?? '/home';

    return PrototypeDetailScaffold(
      title: context.tr.accountTitle,
      fallbackRoute: hubPath,
      body: AdaptiveContent(
        child: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
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
            const SizedBox(height: PrototypeSpacing.listGap),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(context.tr.accountProfileTitle),
                    trailing: const Icon(Icons.chevron_right),
                    selected: selected == '/account/profile',
                    onTap: () => context.push('/account/profile'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(context.tr.settingsTitle),
                    trailing: const Icon(Icons.chevron_right),
                    selected: selected == '/settings',
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(context.tr.help),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr.helpCenter)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xl),
            OutlinedButton(
              onPressed: () {
                store.signOut();
                context.go('/login');
              },
              child: Text(context.tr.signOut),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveAccountPage extends LScopedView<AccountController> {
  const _LiveAccountPage();

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
    final hubPath = GuardianShellScope.maybeOf(context)?.hubPath ?? '/home';

    return PrototypeDetailScaffold(
      title: context.tr.accountTitle,
      fallbackRoute: hubPath,
      body: AdaptiveContent(
        child: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
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
            const SizedBox(height: PrototypeSpacing.listGap),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(context.tr.accountProfileTitle),
                    trailing: const Icon(Icons.chevron_right),
                    selected: selected == '/account/profile',
                    onTap: () => context.push('/account/profile'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(context.tr.settingsTitle),
                    trailing: const Icon(Icons.chevron_right),
                    selected: selected == '/settings',
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(context.tr.help),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr.helpCenter)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xl),
            if (DemoAccess.of(context)?.store != null)
              const DemoButton()
            else
              OutlinedButton(
                onPressed: () async {
                  await controller.signOut();
                  if (context.mounted) context.go('/login');
                },
                child: Text(
                  user == null ? context.tr.signOut : context.tr.signOut,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
