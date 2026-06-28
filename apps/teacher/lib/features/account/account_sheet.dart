import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../auth/session_storage.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppRuntime.session;
    final staffContext = AppRuntime.staffContext;

    return AccountSheetBody(
      session: session,
      sessionStorage: SessionStorage(),
      profileHeader: LWatch(
        () {
          final name = staffContext.staffName.value ?? 'Teacher';
          final email = session.user.value?.email ?? 'Unknown user';
          final initials = name
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .map((part) => part[0])
              .take(2)
              .join()
              .toUpperCase();
          return Row(
            children: [
              PersonAvatar(
                name: name,
                initials: initials.isEmpty ? '?' : initials,
                photoUrl: staffContext.staffPhotoUrl.value,
                radius: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(email),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
