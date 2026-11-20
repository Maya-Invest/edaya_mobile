import 'localized_auth_error.dart';
import 'dart:async';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:flutter/widgets.dart';
import 'otp_delivery_state.dart';

import '../../l10n/l10n_lookup.dart';
import 'app_session_controller.dart';

enum LoginMode {
  enterEmail,
  teacherCode,
  verifyOtp,
  register,
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
    this.invitationToken,
    required Future<void> Function() onSignInSuccess,
  }) : _authClient = authClient,
       _session = session,
       _onSignInSuccess = onSignInSuccess {
    email(defaultEmail);
  }

  final bool startWithEnrollment;
  final String? Function()? invitationToken;
  final registrationEligible = LxVar(false);
  Timer? _proofExpiry;
  void _discardProof() {
    _proofExpiry?.cancel();
    _authClient.registration = null;
  }

  final AuthClient _authClient;
  final AppSessionController _session;
  final Future<void> Function() _onSignInSuccess;
  final email = LxVar('');
  final otp = LxVar('');
  final otpText = TextEditingController();
  late final delivery = OtpDeliveryState(
    _authClient,
    input: otpText,
    onInputChanged: otp.call,
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
  final terms = LxVar<AuthTerms?>(null);
  final termsAccepted = LxVar(false);
  final termsLoading = LxVar(true);
  final termsLoadError = LxVar(false);
  String? _termsLocale;
  String? _acceptedIdentifier;
  int _termsRequest = 0;
  bool _closed = false;

  bool get termsReady =>
      terms.value != null &&
      !termsLoading.value &&
      !termsLoadError.value &&
      (!terms.value!.enforced ||
          (terms.value!.document != null &&
              termsAccepted.value &&
              _acceptedIdentifier == email.value.trim().toLowerCase()));

  void setTermsAccepted(bool accepted) {
    termsAccepted(accepted);
    _acceptedIdentifier = accepted ? email.value.trim().toLowerCase() : null;
  }

  void setEmail(String value) {
    if (value.trim().toLowerCase() != email.value.trim().toLowerCase()) {
      setTermsAccepted(false);
      _discardProof();
    }
    email(value);
  }

  Future<void> loadTerms({String? locale}) async {
    final selectedLocale =
        locale ?? (systemL10n().localeName.startsWith('en') ? 'en' : 'fr');
    final request = ++_termsRequest;
    final previous = terms.value?.document;
    if (_termsLocale != selectedLocale) setTermsAccepted(false);
    _termsLocale = selectedLocale;
    termsLoading(true);
    termsLoadError(false);
    final result = await _authClient.getTerms(locale: selectedLocale);
    if (_closed || request != _termsRequest) return;
    if (!result.isSuccess || result.data == null) {
      terms(null);
      setTermsAccepted(false);
      termsLoadError(true);
    } else {
      final document = result.data!.document;
      if (previous?.version != document?.version ||
          previous?.documentHash != document?.documentHash) {
        setTermsAccepted(false);
      }
      terms(result.data);
    }
    termsLoading(false);
  }

  void syncTermsLocale(String locale) {
    if (!startWithEnrollment && _termsLocale != locale) {
      loadTerms(locale: locale);
    }
  }

  final errorMessage = LxVar('');
  final mode = LxVar(LoginMode.enterEmail);

  @override
  void onInit() {
    super.onInit();
    autoDispose(email);
    autoDispose(registrationEligible);
    autoDispose(terms);
    autoDispose(termsAccepted);
    autoDispose(termsLoading);
    autoDispose(termsLoadError);
    if (!startWithEnrollment) loadTerms();
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
    _closed = true;
    _discardProof();
    delivery.close();
    otpText.dispose();
    super.onClose();
  }

  Future<void> beginEnrollment() async {
    await runTask(() async {
      final result = await _authClient.beginTotpEnrollment();
      if (!result.isSuccess) {
        errorMessage(
          localizedAuthError(result.error, systemL10n().signInFailed),
        );
        return;
      }
      enrollmentSecret(_authClient.enrollmentSecret ?? '');
    }, id: 'enroll-totp');
  }

  void showEmailEntry() {
    _discardProof();
    setTermsAccepted(false);
    errorMessage('');
    _setOtp('');
    mode(LoginMode.enterEmail);
  }

  Future<void> submit() async {
    if (isBusy.value) return;
    switch (mode.value) {
      case LoginMode.teacherCode:
        if (!termsReady) return;
        await runTask(() async {
          final document = terms.value?.document;
          final result = await _authClient.teacherCode(
            otp.value,
            terms.value!.enforced && document != null
                ? AuthTermsAcceptance(
                    version: document.version,
                    locale: document.locale,
                    accepted: true,
                  )
                : null,
          );
          if (result.error?.code == 'terms_version_changed' ||
              result.error?.code == 'terms_acceptance_required') {
            setTermsAccepted(false);
            await loadTerms();
            errorMessage(systemL10n().termsChanged);
            return;
          }
          if (result.error?.code == 'invalid_code') {
            errorMessage(systemL10n().teacherQuickInvalid);
            return;
          }
          _setOtp('');
          await _finishAuth(result);
        }, id: 'teacher-code');
      case LoginMode.register:
        await createAccount();
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
    if (!termsReady) {
      errorMessage(
        termsLoadError.value
            ? systemL10n().termsUnavailable
            : systemL10n().termsRequired,
      );
      return;
    }
    await runTask(() async {
      final document = terms.value?.document;
      final result = await _authClient.sendOtp(
        invitationToken: invitationToken?.call(),
        termsAcceptance: terms.value!.enforced && document != null
            ? AuthTermsAcceptance(
                version: document.version,
                locale: document.locale,
                accepted: true,
              )
            : null,
        value: identifier.value,
        channel: identifier.kind,
        locale: systemL10n().localeName.startsWith('en') ? 'en' : 'fr',
      );
      delivery.refresh();
      if (!result.isSuccess) {
        if (_deliveryFailure(result.error?.code)) return;
        if (result.error?.code == 'terms_version_changed' ||
            result.error?.code == 'terms_acceptance_required') {
          setTermsAccepted(false);
          await loadTerms();
          errorMessage(
            result.error?.code == 'terms_version_changed'
                ? systemL10n().termsChanged
                : systemL10n().termsRequired,
          );
        } else {
          errorMessage(
            result.error?.code == 'terms_unavailable'
                ? systemL10n().termsUnavailable
                : localizedAuthError(result.error, systemL10n().otpSendFailed),
          );
        }
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
        if (_deliveryFailure(result.error?.code)) return;
        if (result.error?.code == 'terms_version_changed' ||
            result.error?.code == 'terms_acceptance_required') {
          setTermsAccepted(false);
          await loadTerms();
          errorMessage(
            result.error?.code == 'terms_version_changed'
                ? systemL10n().termsChanged
                : systemL10n().termsRequired,
          );
        } else {
          errorMessage(
            result.error?.code == 'terms_unavailable'
                ? systemL10n().termsUnavailable
                : localizedAuthError(result.error, systemL10n().otpSendFailed),
          );
        }
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

  bool _deliveryFailure(String? code) {
    if (code == 'delivery_unavailable') {
      showEmailEntry();
      errorMessage(systemL10n().otpSendFailed);
      return true;
    }
    if (code == 'NETWORK_ERROR') {
      errorMessage(systemL10n().emailSendUnconfirmed);
      return true;
    }
    return false;
  }

  Future<void> createAccount() async {
    final offer = _authClient.registration;
    if (offer == null || !registrationEligible.value || !termsReady) return;
    await runTask(() async {
      errorMessage('');
      final document = terms.value?.document;
      final accepted = terms.value?.enforced == true && document != null
          ? AuthTermsAcceptance(
              version: document.version,
              locale: document.locale,
              accepted: true,
            )
          : null;
      final result = await _authClient.completeRegistration(offer, accepted);
      if (_closed) return;
      switch (result.error?.code) {
        case 'terms_version_changed':
        case 'terms_acceptance_required':
          setTermsAccepted(false);
          await loadTerms();
          errorMessage(systemL10n().termsChanged);
          return;
        case 'registration_unavailable':
          registrationEligible(false);
          return;
        case 'NETWORK_ERROR':
        case 'authentication_unavailable':
          final session = await _authClient.getSession();
          if (_closed) return;
          final user = session.data?.user;
          if (user != null &&
              user.email.toLowerCase() == email.value.trim().toLowerCase()) {
            _discardProof();
            await _completeSession(user);
            return;
          }
          showEmailEntry();
          errorMessage(systemL10n().restartEmailVerification);
          return;
        case 'registration_expired':
          showEmailEntry();
          errorMessage(systemL10n().restartEmailVerification);
          return;
      }
      _discardProof();
      await _finishAuth(result);
    }, id: 'register');
  }

  void useRecovery() {
    _setOtp('');
    mode(LoginMode.recovery);
  }

  Future<void> _finishAuth(AuthResult<AuthUser> result) async {
    if (_closed) {
      _discardProof();
      return;
    }
    final offer = _authClient.registration;
    if (result.error?.code == 'registration_required' && offer != null) {
      _setOtp('');
      registrationEligible(offer.eligible);
      mode(LoginMode.register);
      _proofExpiry?.cancel();
      _proofExpiry = Timer(
        Duration(
          milliseconds:
              offer.expiresAt.toInt() - DateTime.now().millisecondsSinceEpoch,
        ),
        () {
          if (!_closed && mode.value == LoginMode.register && !isBusy.value) {
            showEmailEntry();
            errorMessage(systemL10n().restartEmailVerification);
          }
        },
      );
      return;
    }
    if (result.error?.code == 'totp_required') {
      _setOtp('');
      mode(LoginMode.verifyTotp);
      return;
    }
    if (result.error?.code == 'enrollment_required') {
      final enrollment = await _authClient.beginTotpEnrollment();
      if (!enrollment.isSuccess) {
        errorMessage(
          localizedAuthError(enrollment.error, systemL10n().signInFailed),
        );
        return;
      }
      enrollmentSecret(_authClient.enrollmentSecret ?? '');
      _setOtp('');
      mode(LoginMode.enrollTotp);
      return;
    }
    if (!result.isSuccess || result.data == null) {
      errorMessage(localizedAuthError(result.error, systemL10n().signInFailed));
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
