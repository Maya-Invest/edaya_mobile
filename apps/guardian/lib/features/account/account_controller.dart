import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/student_context_controller.dart';

class AccountController extends LevitController {
  AccountController({
    required AppSessionController session,
    required StudentContextController studentContext,
  }) : _session = session,
       _studentContext = studentContext;

  final AppSessionController _session;
  final StudentContextController _studentContext;

  AppSessionController get session => _session;

  String get displayName {
    final user = _session.user.value;
    if (user == null) return 'Parent';
    final name = user.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    return user.email.isNotEmpty ? user.email : 'Parent';
  }

  String get email => _session.user.value?.email ?? '';

  String get initials {
    final user = _session.user.value;
    final name = user?.name?.trim() ?? '';
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    final mail = user?.email ?? '';
    if (mail.isNotEmpty) return mail[0].toUpperCase();
    return 'P';
  }

  Future<void> signOut() async {
    await _studentContext.clearStudent();
    await _session.signOut();
  }
}
