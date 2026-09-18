import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import '../context/teacher_context_controller.dart';

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

    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text('Compte', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: PrototypeSpacing.md),
          SurfaceCard(
            child: Row(
              children: [
                PersonAvatar(initials: store.teacherInitials, radius: 28),
                const SizedBox(width: PrototypeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.teacherFullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        store.teacher.email,
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
              store.signOut();
              context.go('/login');
            },
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}

class AccountProfilePage extends StatelessWidget {
  const AccountProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveAccountProfilePage();
    }
    final store = context.levit.find<MockStore>();
    return PrototypeDetailScaffold(
      title: 'Profil',
      fallbackRoute: '/account',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          ListTile(
            title: const Text('Nom'),
            subtitle: Text(store.teacherFullName),
          ),
          ListTile(
            title: const Text('E-mail'),
            subtitle: Text(store.teacher.email),
          ),
          const ListTile(
            title: Text('Téléphone'),
            subtitle: Text('+225 07 00 00 00'),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrototypeDetailScaffold(
      title: 'Paramètres',
      fallbackRoute: '/account',
      body: Padding(
        padding: EdgeInsets.all(PrototypeSpacing.md),
        child: EmptyState(
          title: 'Paramètres',
          message: 'Prototype — les réglages seront branchés plus tard.',
        ),
      ),
    );
  }
}

class _LiveAccountPage extends StatelessWidget {
  const _LiveAccountPage();

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final session = context.levit.find<AppSessionController>();
      final teacherContext = context.levit.find<TeacherContextController>();
      session.user.value;
      teacherContext.teacherName.value;
      teacherContext.teacherPhotoUrl.value;
      final selected = GoRouterState.of(context).uri.path;
      final user = session.user.value;
      final name = teacherContext.teacherName.value ?? user?.name ?? '';
      return AdaptiveContent(
        child: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            Text('Compte', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: PrototypeSpacing.md),
            SurfaceCard(
              child: Row(
                children: [
                  PersonAvatar(
                    initials: teacherContext.teacherInitials,
                    photoUrl: teacherContext.teacherPhotoUrl.value,
                    radius: 28,
                  ),
                  const SizedBox(width: PrototypeSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          user?.email ?? '',
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
                await session.signOut();
                if (!context.mounted) return;
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

class _LiveAccountProfilePage extends StatelessWidget {
  const _LiveAccountProfilePage();

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final session = context.levit.find<AppSessionController>();
      final teacherContext = context.levit.find<TeacherContextController>();
      session.user.value;
      teacherContext.teacherName.value;
      final user = session.user.value;
      return PrototypeDetailScaffold(
        title: 'Profil',
        fallbackRoute: '/account',
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            ListTile(
              title: const Text('Nom'),
              subtitle: Text(
                teacherContext.teacherName.value ?? user?.name ?? '',
              ),
            ),
            ListTile(
              title: const Text('E-mail'),
              subtitle: Text(user?.email ?? ''),
            ),
          ],
        ),
      );
    });
  }
}
