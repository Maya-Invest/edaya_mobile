import 'package:edaya_shared/edaya_shared.dart' as edaya;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// Prototype route page — delegates to shared profile editor.
class AccountProfilePage extends StatelessWidget {
  const AccountProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return edaya.AccountProfilePage(
      session: context.levit.find<edaya.AppSessionController>(),
      schoolClient: context.levit.find<edaya.SchoolClientFactory>(),
    );
  }
}
