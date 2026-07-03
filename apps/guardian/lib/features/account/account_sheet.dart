import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../access/app_runtime.dart';
import '../auth/session_storage.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppRuntime.session;

    return AccountSheetBody(
      session: session,
      sessionStorage: SessionStorage(),
      profileHeader: AccountProfileHeader(
        session: session,
        schoolClient: AppRuntime.schoolClient,
        onTap: () {
          context.pop();
          context.push('/account/profile');
        },
      ),
    );
  }
}
