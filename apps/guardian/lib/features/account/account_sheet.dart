import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../../access/app_runtime.dart';
import '../auth/session_storage.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppRuntime.session;
    final user = session.user.value;

    return AccountSheetBody(
      session: session,
      sessionStorage: SessionStorage(),
      profileHeader: Text(user?.email ?? context.tr.unknownUser),
    );
  }
}
