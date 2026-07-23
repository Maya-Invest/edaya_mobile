import 'package:edaya_shared/edaya_shared.dart' as edaya;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'settings_controller.dart';

/// Prototype settings route — shared preferences + optional API URL override.
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
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    // Shared settings page owns its scaffold; when embedded in the detail drawer
    // we show a compact French summary + developer URL controls.
    if (!embedded) {
      return const edaya.SettingsPage();
    }

    return PrototypeDetailScaffold(
      embedded: true,
      fallbackRoute: '/account',
      title: 'Paramètres',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          const SectionHeader(title: 'Préférences'),
          SurfaceCard(
            child: ListTile(
              title: const Text('Ouvrir les paramètres complets'),
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
          if (edaya.DeveloperSettingsConfig.enabled) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            const SectionHeader(title: 'Développeur'),
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
