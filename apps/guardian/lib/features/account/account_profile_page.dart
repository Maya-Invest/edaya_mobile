import 'package:edaya_shared/edaya_shared.dart' as edaya;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';

/// route page — delegates to shared profile editor.
class AccountProfilePage extends StatelessWidget {
  const AccountProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return PrototypeDetailScaffold(
        title: edaya.systemL10n().accountProfileTitle,
        fallbackRoute: '/account',
        body: edaya.AccountProfilePage(
          session: context.levit.find<edaya.AppSessionController>(),
          schoolClient: context.levit.find<edaya.SchoolClientFactory>(),
          embedded: true,
        ),
      );
    }
    final store = context.levit.find<MockStore>();
    return PrototypeDetailScaffold(
      title: edaya.systemL10n().accountProfileTitle,
      fallbackRoute: '/account',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          ListTile(
            title: Text(edaya.systemL10n().name),
            subtitle: Text(store.guardianFullName),
          ),
          ListTile(
            title: const Text('E-mail'),
            subtitle: Text(MockStore.guardianEmail),
          ),
        ],
      ),
    );
  }
}
