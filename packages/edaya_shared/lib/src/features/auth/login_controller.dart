import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../config/developer_settings_config.dart';
import '../../l10n/l10n_lookup.dart';
import 'app_session_controller.dart';

enum LoginMode { enterEmail, verifyOtp }

class LoginController extends LevitController with LevitReactiveTasksMixin {
  LoginController({
    required AuthClient authClient,
    required AppSessionController session,
    required String defaultEmail,
    required Future<void> Function() onSignInSuccess,
  }) : _authClient = authClient,
       _session = session,
       _onSignInSuccess = onSignInSuccess {
    email(defaultEmail);
  }

  final AuthClient _authClient;
  final AppSessionController _session;
  final Future<void> Function() _onSignInSuccess;
  final email = LxVar('');
  final otp = LxVar('');
  final errorMessage = LxVar('');
  final mode = LxVar(LoginMode.enterEmail);

  @override
  void onInit() {
    super.onInit();
    autoDispose(email);
    autoDispose(otp);
    autoDispose(errorMessage);
    autoDispose(mode);
  }

  void showEmailEntry() {
    errorMessage('');
    otp('');
    mode(LoginMode.enterEmail);
  }

  Future<void> submit() async {
    switch (mode.value) {
      case LoginMode.enterEmail:
        await sendCode();
      case LoginMode.verifyOtp:
        await verifyOtp();
    }
  }

  Future<void> sendCode() async {
    errorMessage('');
    final trimmedEmail = email.value.trim();
    if (trimmedEmail.isEmpty) {
      errorMessage(systemL10n().emailRequired);
      return;
    }
    await runTask(() async {
      final result = await _authClient.sendEmailOtp(email: trimmedEmail);
      if (!result.isSuccess) {
        errorMessage(result.error?.message ?? systemL10n().otpSendFailed);
        return;
      }
      var nextOtp = '';
      if (DeveloperSettingsConfig.enabled) {
        final peek = await _authClient.peekDevLastOtp(email: trimmedEmail);
        if (peek.isSuccess && peek.data != null) {
          nextOtp = peek.data!.trim();
        }
      }
      otp(nextOtp);
      mode(LoginMode.verifyOtp);
    }, id: 'send-otp');
  }

  Future<void> verifyOtp() async {
    errorMessage('');
    await runTask(() async {
      final result = await _authClient.signInWithEmailOtp(
        email: email.value.trim(),
        otp: otp.value.trim(),
      );
      await _finishAuth(result);
    }, id: 'verify-otp');
  }

  Future<void> resendOtp() async {
    errorMessage('');
    await runTask(() async {
      final result = await _authClient.sendEmailOtp(email: email.value.trim());
      if (!result.isSuccess) {
        errorMessage(result.error?.message ?? systemL10n().otpSendFailed);
      }
    }, id: 'resend-otp');
  }

  Future<void> _finishAuth(AuthResult<AuthUser> result) async {
    if (!result.isSuccess || result.data == null) {
      errorMessage(result.error?.message ?? systemL10n().signInFailed);
      return;
    }
    await _completeSession(result.data!);
  }

  Future<void> _completeSession(AuthUser signedInUser) async {
    final sessionError = await _session.completeSignIn(signedInUser);
    if (sessionError != null) {
      errorMessage(sessionError);
      return;
    }
    await _onSignInSuccess();
  }
}
