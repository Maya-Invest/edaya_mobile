import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/components/components.dart';
import '../design/spacing.dart';
import '../mock/mock_store.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PrototypeDetailScaffold(
      fallbackRoute: '/account',
      title: 'Paramètres',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          const SectionHeader(title: 'Apparence'),
          SurfaceCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Mode sombre'),
                  value: false,
                  onChanged: (_) {},
                ),
                const Divider(),
                ListTile(
                  title: const Text('Langue'),
                  trailing: const Text('Français'),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          const SectionHeader(title: 'Formats'),
          SurfaceCard(
            child: Column(
              children: [
                ListTile(title: const Text('Fuseau horaire'), trailing: const Text('Africa/Abidjan')),
                const Divider(),
                ListTile(title: const Text('Format de date'), trailing: const Text('JJ/MM/AAAA')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.store});

  final MockStore store;

  @override
  Widget build(BuildContext context) {
    return PrototypeDetailScaffold(
      fallbackRoute: '/home',
      title: 'Compte',
      body: ListView(
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
                      Text(store.guardianFullName, style: Theme.of(context).textTheme.titleMedium),
                      Text(MockStore.guardianEmail, style: Theme.of(context).textTheme.bodySmall),
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
                  onTap: () => context.push('/account/profile'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Paramètres'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings'),
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
    return PrototypeDetailScaffold(
      fallbackRoute: '/account',
      title: 'Profil de contact',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Prénom'),
            controller: TextEditingController(text: 'Moussa'),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          TextField(
            decoration: const InputDecoration(labelText: 'Nom'),
            controller: TextEditingController(text: 'Koné'),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          TextField(
            decoration: const InputDecoration(labelText: 'Téléphone'),
            controller: TextEditingController(text: '+225 07 00 00 00 00'),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          FilledButton(
            onPressed: () => PrototypeDetailScaffold.popOrGo(
              context,
              fallbackRoute: '/account',
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
