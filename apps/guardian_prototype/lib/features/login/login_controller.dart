import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/student_context_controller.dart';

class LoginController extends LevitController {
  LoginController({required this.studentContext});

  final StudentContextController studentContext;

  late final email = TextEditingController(text: 'parent@demo.ci');
  late final password = TextEditingController(text: '••••••••');

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    super.onClose();
  }

  void signIn() => studentContext.signIn();
}
