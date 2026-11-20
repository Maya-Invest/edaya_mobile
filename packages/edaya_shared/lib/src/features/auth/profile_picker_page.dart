import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../l10n/l10n_lookup.dart';
import 'app_session_controller.dart';

class ProfilePickerPage extends StatelessWidget {
  const ProfilePickerPage({super.key, required this.onSelected});

  final void Function() onSelected;

  @override
  Widget build(BuildContext context) {
    final session = context.levit.find<AppSessionController>();
    return Scaffold(
      appBar: AppBar(title: Text(systemL10n().chooseSchool)),
      body: LWatch(() {
        final profiles = session.availableProfiles.value;
        return ListView(
          children: [
            for (final profile in profiles)
              ListTile(
                title: Text(profile.label),
                subtitle: Text(profile.schoolName),
                onTap: () async {
                  final error = await session.selectProfile(profile);
                  if (!context.mounted) {
                    return;
                  }
                  if (error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                    return;
                  }
                  onSelected();
                },
              ),
          ],
        );
      }),
    );
  }
}
