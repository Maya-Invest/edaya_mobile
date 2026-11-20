import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import 'account_profile_data.dart';

class AccountProfileHeader extends StatefulWidget {
  const AccountProfileHeader({
    super.key,
    required this.session,
    required this.schoolClient,
    this.onTap,
  });

  final AppSessionController session;
  final api.SchoolClient Function() schoolClient;
  final VoidCallback? onTap;

  @override
  State<AccountProfileHeader> createState() => _AccountProfileHeaderState();
}

class _AccountProfileHeaderState extends State<AccountProfileHeader> {
  AccountContactProfile? _profile;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final grants = widget.session.grants.value;
    if (grants == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final loaded = await loadAccountContactProfile(
        widget.schoolClient(),
        kind: grants.kind,
        actorId: grants.actorId,
      );
      if (mounted) {
        setState(() {
          _profile = loaded;
          _loading = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = _profile;
    final loginEmail =
        widget.session.user.value?.email ?? context.tr.unknownUser;
    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : loginEmail;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            PersonAvatar(
              name: displayName,
              initials: profile?.initials ?? '?',
              photoUrl: profile?.photoUrl,
              radius: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.email?.isNotEmpty == true
                        ? profile!.email!
                        : loginEmail,
                  ),
                  if (profile?.phone?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(profile!.phone!),
                  ],
                ],
              ),
            ),
            if (widget.onTap != null)
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
