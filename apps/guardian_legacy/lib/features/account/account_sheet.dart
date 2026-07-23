import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.levit.find<AppSessionController>();
    final schoolClient = context.levit.find<SchoolClientFactory>();

    return AccountSheetBody(
      session: session,
      profileHeader: AccountProfileHeader(
        session: session,
        schoolClient: schoolClient,
        onTap: () {
          context.pop();
          context.push('/account/profile');
        },
      ),
    );
  }
}
