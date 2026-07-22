import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'account_profile_controller.dart';

class AccountProfilePage extends LScopedView<AccountProfileController> {
  const AccountProfilePage({super.key});

  @override
  AccountProfileController onConfigScope(LevitScope scope) {
    return scope.put(() => AccountProfileController());
  }

  @override
  Widget buildView(BuildContext context, AccountProfileController controller) {
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    return PrototypeDetailScaffold(
      embedded: embedded,
      fallbackRoute: '/account',
      title: 'Profil de contact',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Prénom'),
            controller: controller.firstName,
          ),
          const SizedBox(height: PrototypeSpacing.md),
          TextField(
            decoration: const InputDecoration(labelText: 'Nom'),
            controller: controller.lastName,
          ),
          const SizedBox(height: PrototypeSpacing.md),
          TextField(
            decoration: const InputDecoration(labelText: 'Téléphone'),
            controller: controller.phone,
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
