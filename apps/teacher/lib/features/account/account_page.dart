import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart' as edaya;
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
import '../offline/teacher_outbox_controller.dart';
import 'settings_controller.dart';

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
      return edaya.AccountProfilePage(
        session: context.levit.find<AppSessionController>(),
        schoolClient: context.levit.find<SchoolClientFactory>(),
        onProfileSaved: (_) =>
            context.levit.find<TeacherContextController>().reloadContext(),
      );
    }
    final store = context.levit.find<MockStore>();
    return PrototypeDetailScaffold(
      title: context.tr.accountProfileTitle,
      fallbackRoute: '/account',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          ListTile(
            title: Text(context.tr.lastNameLabel),
            subtitle: Text(store.teacherFullName),
          ),
          ListTile(
            title: Text(context.tr.emailLabel),
            subtitle: Text(store.teacher.email),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends LScopedView<SettingsController> {
  const SettingsPage({super.key});

  @override
  SettingsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SettingsController(
        settings: scope.find<edaya.AppSettingsController>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SettingsController controller) {
    TeacherOutboxController? outbox;
    try {
      outbox = context.levit.find<TeacherOutboxController>();
    } on Object {
      outbox = null;
    }
    return PrototypeDetailScaffold(
      fallbackRoute: '/account',
      title: context.tr.settingsTitle,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SectionHeader(title: context.tr.settingsTitle),
          SurfaceCard(
            child: ListTile(
              title: Text(context.tr.settingsTitle),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const edaya.SettingsPage(),
                  ),
                );
              },
            ),
          ),
          if (outbox != null) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            LWatch(
              () => TeacherOutboxSyncSummaryCard(
                summary: outbox!.summary.value,
                isSyncing: outbox.isBusy.value,
                onSyncNow: () => unawaited(outbox!.syncPending()),
              ),
            ),
          ],
          if (edaya.DeveloperSettingsConfig.enabled) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            SectionHeader(title: context.tr.developerSettings),
            const SurfaceCard(
              child: Padding(
                padding: EdgeInsets.all(PrototypeSpacing.sm),
                child: edaya.DevApiUrlSettings(compact: true),
              ),
            ),
          ],
        ],
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
      final outbox = context.levit.find<TeacherOutboxController>();
      session.user.value;
      teacherContext.teacherName.value;
      teacherContext.teacherPhotoUrl.value;
      outbox.summary.value;
      outbox.isBusy.value;
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
                    title: Text(context.tr.accountProfileTitle),
                    trailing: const Icon(Icons.chevron_right),
                    selected: selected == '/account/profile',
                    onTap: () => context.go('/account/profile'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(context.tr.settingsTitle),
                    trailing: const Icon(Icons.chevron_right),
                    selected: selected == '/settings',
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.md),
            TeacherOutboxSyncSummaryCard(
              summary: outbox.summary.value,
              isSyncing: outbox.isBusy.value,
              onSyncNow: () => unawaited(outbox.syncPending()),
            ),
            const SizedBox(height: PrototypeSpacing.xl),
            OutlinedButton(
              onPressed: () async {
                await session.signOut();
                if (!context.mounted) return;
                context.go('/login');
              },
              child: Text(context.tr.signOut),
            ),
          ],
        ),
      );
    });
  }
}
