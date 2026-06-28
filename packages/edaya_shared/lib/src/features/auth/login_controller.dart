import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'app_session_controller.dart';

class LoginController extends LevitController with LevitReactiveTasksMixin {
  LoginController({
    required AuthClient authClient,
    required AppSessionController session,
    required String defaultEmail,
    required String defaultPassword,
    required Future<void> Function() onSignInSuccess,
  }) : _authClient = authClient,
       _session = session,
       _onSignInSuccess = onSignInSuccess {
    email(defaultEmail);
    password(defaultPassword);
  }

  final AuthClient _authClient;
  final AppSessionController _session;
  final Future<void> Function() _onSignInSuccess;
  final email = LxVar('');
  final password = LxVar('');
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(email);
    autoDispose(password);
    autoDispose(errorMessage);
  }

  Future<void> signInWithPassword() async {
    errorMessage('');
    await runTask(() async {
      final result = await _authClient.signInWithEmail(
        email: email.value.trim(),
        password: password.value,
      );

      if (!result.isSuccess || result.data == null) {
        errorMessage(result.error?.message ?? 'Sign-in failed');
        return;
      }

      final sessionError = await _session.completeSignIn(result.data!);
      if (sessionError != null) {
        errorMessage(sessionError);
        return;
      }

      await _onSignInSuccess();
    }, id: 'sign-in');
  }
}
