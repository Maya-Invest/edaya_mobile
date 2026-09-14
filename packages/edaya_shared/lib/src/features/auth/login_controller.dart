import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../l10n/l10n_lookup.dart';
import 'app_session_controller.dart';

enum LoginMode { signIn, signUp, verifyOtp }

class LoginController extends LevitController with LevitReactiveTasksMixin {
  LoginController({
    required AuthClient authClient,
    required AppSessionController session,
    required String defaultEmail,
    required String defaultPassword,
    required Future<void> Function() onSignInSuccess,
    this.enableSignUp = false,
  }) : _authClient = authClient,
       _session = session,
       _onSignInSuccess = onSignInSuccess {
    email(defaultEmail);
    password(defaultPassword);
  }

  final AuthClient _authClient;
  final AppSessionController _session;
  final Future<void> Function() _onSignInSuccess;
  final bool enableSignUp;
  final email = LxVar('');
  final password = LxVar('');
  final name = LxVar('');
  final otp = LxVar('');
  final errorMessage = LxVar('');
  final mode = LxVar(LoginMode.signIn);

  @override
  void onInit() {
    super.onInit();
    autoDispose(email);
    autoDispose(password);
    autoDispose(name);
    autoDispose(otp);
    autoDispose(errorMessage);
    autoDispose(mode);
  }

  void showSignIn() {
    errorMessage('');
    otp('');
    mode(LoginMode.signIn);
  }

  void showSignUp() {
    if (!enableSignUp) {
      return;
    }
    errorMessage('');
    otp('');
    mode(LoginMode.signUp);
  }

  Future<void> submit() async {
    switch (mode.value) {
      case LoginMode.signIn:
        await signInWithPassword();
      case LoginMode.signUp:
        await signUpWithPassword();
      case LoginMode.verifyOtp:
        await verifyOtp();
    }
  }

  Future<void> signInWithPassword() async {
    errorMessage('');
    await runTask(() async {
      final result = await _authClient.signInWithEmail(
        email: email.value.trim(),
        password: password.value,
      );
      await _finishAuth(result);
    }, id: 'sign-in');
  }

  Future<void> signUpWithPassword() async {
    if (!enableSignUp) {
      return;
    }
    errorMessage('');
    final displayName = name.value.trim();
    if (displayName.isEmpty) {
      errorMessage(systemL10n().fullNameRequired);
      return;
    }
    await runTask(() async {
      final result = await _authClient.signUpWithEmail(
        email: email.value.trim(),
        password: password.value,
        name: displayName,
      );
      if (!result.isSuccess || result.data == null) {
        errorMessage(result.error?.message ?? systemL10n().signUpFailed);
        return;
      }
      if (_authClient.renewalCredential == null) {
        final otpResult = await _authClient.sendEmailOtp(
          email: email.value.trim(),
        );
        if (!otpResult.isSuccess) {
          errorMessage(otpResult.error?.message ?? systemL10n().signUpFailed);
          return;
        }
        otp('');
        mode(LoginMode.verifyOtp);
        return;
      }
      await _completeSession(result.data!);
    }, id: 'sign-up');
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
        errorMessage(result.error?.message ?? systemL10n().signUpFailed);
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
