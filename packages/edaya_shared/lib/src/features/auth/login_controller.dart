import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:flutter/widgets.dart';
import 'otp_delivery_state.dart';

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
  final otpText = TextEditingController();
  late final delivery = OtpDeliveryState(
    _authClient,
    active: () => mode.value == LoginMode.verifyOtp,
    busy: () => isBusy.value,
  );
  void _setOtp(String value) {
    otp(value);
    otpText.text = value;
  }

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
    autoDispose(enrollmentSecret);
    autoDispose(recoveryCodes);
    autoDispose(errorMessage);
    autoDispose(mode);
    delivery.start();
    if (startWithEnrollment) {
      mode(LoginMode.enrollTotp);
      beginEnrollment();
    }
  }

  @override
  void onClose() {
    delivery.close();
    otpText.dispose();
    super.onClose();
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
    _setOtp('');
    mode(LoginMode.enterEmail);
  }

  Future<void> submit() async {
    if (isBusy.value) return;
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
    final identifier = LoginIdentifier.detect(email.value);
    if (identifier == null) {
      errorMessage(systemL10n().invalidContact);
      return;
    }
    if (identifier.kind == 'phone' && !delivery.phoneAvailable.value) {
      errorMessage(systemL10n().phoneUnavailable);
      return;
    }
    await runTask(() async {
      final result = await _authClient.sendOtp(
        value: identifier.value,
        channel: identifier.kind,
        locale: systemL10n().localeName.startsWith('en') ? 'en' : 'fr',
      );
      delivery.refresh();
      if (!result.isSuccess) {
        errorMessage(result.error?.message ?? systemL10n().otpSendFailed);
        return;
      }
      _setOtp('');
      delivery.refresh();
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

  Future<void> resendOtp({String action = 'resend'}) async {
    if (action == 'retry'
        ? !delivery.retryable.value
        : action == 'sms'
        ? !delivery.canSms
        : !delivery.canResend) {
      return;
    }
    errorMessage('');
    await runTask(() async {
      final result = action == 'retry'
          ? await _authClient.retryOtpRequest()
          : await _authClient.resendOtp(action: action);
      delivery.refresh();
      if (!result.isSuccess) {
        errorMessage(result.error?.message ?? systemL10n().otpSendFailed);
      } else {
        _setOtp('');
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
    _setOtp('');
    mode(LoginMode.recovery);
  }

  Future<void> _finishAuth(AuthResult<AuthUser> result) async {
    if (result.error?.code == 'totp_required') {
      _setOtp('');
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
      _setOtp('');
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
