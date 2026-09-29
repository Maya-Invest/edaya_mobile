import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../config/developer_settings_config.dart';
import '../../l10n/l10n_lookup.dart';
import 'app_session_controller.dart';

enum LoginMode {
  enterEmail,
  verifyOtp,
  verifyTotp,
  recovery,
  enrollTotp,
  saveRecoveryCodes,
}

class LoginController extends LevitController with LevitReactiveTasksMixin {
  LoginController({
    required AuthClient authClient,
    required AppSessionController session,
    required String defaultEmail,
    this.startWithEnrollment = false,
    required Future<void> Function() onSignInSuccess,
  }) : _authClient = authClient,
       _session = session,
       _onSignInSuccess = onSignInSuccess {
    email(defaultEmail);
  }

  final bool startWithEnrollment;
  final AuthClient _authClient;
  final AppSessionController _session;
  final Future<void> Function() _onSignInSuccess;
  final email = LxVar('');
  final otp = LxVar('');
  final channel = LxVar('email');
  final enrollmentSecret = LxVar('');
  final recoveryCodes = LxVar<List<String>>([]);
  AuthUser? _completedUser;
  final errorMessage = LxVar('');
  final mode = LxVar(LoginMode.enterEmail);

  @override
  void onInit() {
    super.onInit();
    autoDispose(email);
    autoDispose(otp);
    autoDispose(channel);
    autoDispose(enrollmentSecret);
    autoDispose(recoveryCodes);
    autoDispose(errorMessage);
    autoDispose(mode);
    if (startWithEnrollment) {
      mode(LoginMode.enrollTotp);
      beginEnrollment();
    }
  }

  Future<void> beginEnrollment() async {
    await runTask(() async {
      final result = await _authClient.beginTotpEnrollment();
      if (!result.isSuccess) {
        errorMessage(result.error?.message ?? systemL10n().signInFailed);
        return;
      }
      enrollmentSecret(_authClient.enrollmentSecret ?? '');
    }, id: 'enroll-totp');
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
      case LoginMode.verifyTotp:
        await _factor(_authClient.verifyTotp);
      case LoginMode.recovery:
        await _factor(_authClient.recover);
      case LoginMode.enrollTotp:
        await _factor(_authClient.confirmTotp);
      case LoginMode.saveRecoveryCodes:
        final user = _completedUser;
        if (user != null) {
          recoveryCodes([]);
          _authClient.recoveryCodes = [];
          await _completeSession(user);
        }
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
      final result = await _authClient.sendOtp(
        value: trimmedEmail,
        channel: channel.value,
      );
      if (!result.isSuccess) {
        errorMessage(result.error?.message ?? systemL10n().otpSendFailed);
        return;
      }
      var nextOtp = '';
      if (DeveloperSettingsConfig.enabled && channel.value == 'email') {
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
      final result = await _authClient.sendOtp(
        value: email.value.trim(),
        channel: channel.value,
      );
      if (!result.isSuccess) {
        errorMessage(result.error?.message ?? systemL10n().otpSendFailed);
      }
    }, id: 'resend-otp');
  }

  Future<void> _factor(
    Future<AuthResult<AuthUser>> Function(String) action,
  ) async {
    errorMessage('');
    await runTask(() async {
      await _finishAuth(await action(otp.value.trim()));
    }, id: 'verify-factor');
  }

  void useRecovery() {
    otp('');
    mode(LoginMode.recovery);
  }

  Future<void> _finishAuth(AuthResult<AuthUser> result) async {
    if (result.error?.code == 'totp_required') {
      otp('');
      mode(LoginMode.verifyTotp);
      return;
    }
    if (result.error?.code == 'enrollment_required') {
      final enrollment = await _authClient.beginTotpEnrollment();
      if (!enrollment.isSuccess) {
        errorMessage(enrollment.error?.message ?? systemL10n().signInFailed);
        return;
      }
      enrollmentSecret(_authClient.enrollmentSecret ?? '');
      otp('');
      mode(LoginMode.enrollTotp);
      return;
    }
    if (!result.isSuccess || result.data == null) {
      errorMessage(result.error?.message ?? systemL10n().signInFailed);
      return;
    }
    if (_authClient.recoveryCodes.isNotEmpty) {
      _completedUser = result.data!;
      recoveryCodes(List.of(_authClient.recoveryCodes));
      mode(LoginMode.saveRecoveryCodes);
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
