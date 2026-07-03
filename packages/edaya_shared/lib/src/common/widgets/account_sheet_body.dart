import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../config/developer_settings_config.dart';
import '../../config/dev_api_url_settings.dart';
import '../../features/auth/app_session_controller.dart';
import '../../features/auth/auth_session_storage.dart';
import '../../l10n/l10n_extension.dart';

class AccountSheetBody extends StatelessWidget {
  const AccountSheetBody({
    super.key,
    required this.session,
    required this.sessionStorage,
    this.profileHeader,
  });

  final AppSessionController session;
  final AuthSessionStorage sessionStorage;
  final Widget? profileHeader;

  @override
  Widget build(BuildContext context) {
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
                  context.tr.accountTitle,
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
            if (profileHeader != null) ...[
              profileHeader!,
              const SizedBox(height: 24),
            ],
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(context.tr.accountProfileTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.pop();
                context.push('/account/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(context.tr.settingsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.pop();
                context.push('/settings');
              },
            ),
            if (DeveloperSettingsConfig.enabled) ...[
              const SizedBox(height: 8),
              DevApiUrlSettings(
                compact: true,
                onUrlChanged: () async {
                  await sessionStorage.clearCookies();
                  await sessionStorage.markLoggedOut();
                },
              ),
            ],
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
                  session.isSigningOut.value
                      ? context.tr.signingOut
                      : context.tr.signOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
