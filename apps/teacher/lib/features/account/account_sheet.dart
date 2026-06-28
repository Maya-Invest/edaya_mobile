import 'package:edaya_ui/edaya_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppRuntime.session;
    final staffContext = AppRuntime.staffContext;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LWatch(
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            LWatch(
              () => OutlinedButton.icon(
                onPressed: session.isSigningOut.value
                    ? null
                    : () async {
                        await session.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                icon: session.isSigningOut.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(
                  session.isSigningOut.value ? 'Signing out…' : 'Sign out',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
