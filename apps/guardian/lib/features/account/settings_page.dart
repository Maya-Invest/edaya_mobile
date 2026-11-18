import 'package:edaya_shared/edaya_shared.dart' as edaya;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'settings_controller.dart';

/// Settings route — shared preferences + optional API URL override.
class SettingsPage extends LScopedView<SettingsController> {
  const SettingsPage({super.key});

  @override
  SettingsController onConfigScope(LevitScope scope) {
    return scope.put(() => SettingsController(settings: scope.find<edaya.AppSettingsController>()));
  }

  @override
  Widget buildView(BuildContext context, SettingsController controller) {
    final tr = edaya.AppLocalizations.of(context)!;
    return PrototypeDetailScaffold(
      fallbackRoute: '/account',
      title: tr.settingsTitle,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SectionHeader(title: tr.preferences),
          SurfaceCard(
            child: ListTile(
              title: Text(tr.openAllSettings),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const edaya.SettingsPage()));
              },
            ),
          ),
          if (edaya.DemoAccess.of(context)?.store == null && edaya.DeveloperSettingsConfig.enabled) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            SectionHeader(title: tr.developerSettings),
            const SurfaceCard(
              child: Padding(padding: EdgeInsets.all(PrototypeSpacing.sm), child: edaya.DevApiUrlSettings(compact: true)),
            ),
          ],
        ],
      ),
    );
  }
}
