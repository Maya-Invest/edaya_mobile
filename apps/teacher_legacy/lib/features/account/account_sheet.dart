import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../offline/teacher_outbox_controller.dart';

class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key});

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.levit.find<TeacherOutboxController>().refreshSummary());
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.levit.find<AppSessionController>();
    final schoolClient = context.levit.find<SchoolClientFactory>();
    final outbox = context.levit.find<TeacherOutboxController>();

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
      beforeSignOut: LWatch(
        () => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TeacherOutboxSyncSummaryCard(
            summary: outbox.summary.value,
            isSyncing: outbox.isBusy.value,
            onSyncNow: () => unawaited(outbox.syncPending()),
          ),
        ),
      ),
    );
  }
}
