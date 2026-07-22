import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'settings_controller.dart';

class SettingsPage extends LScopedView<SettingsController> {
  const SettingsPage({super.key});

  @override
  SettingsController onConfigScope(LevitScope scope) {
    return scope.put(() => SettingsController());
  }

  @override
  Widget buildView(BuildContext context, SettingsController controller) {
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    return PrototypeDetailScaffold(
      embedded: embedded,
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
                ListTile(
                  title: const Text('Fuseau horaire'),
                  trailing: const Text('Africa/Abidjan'),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Format de date'),
                  trailing: const Text('JJ/MM/AAAA'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
