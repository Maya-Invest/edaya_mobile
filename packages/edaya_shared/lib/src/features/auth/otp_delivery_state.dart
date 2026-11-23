import 'dart:async';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// Owned by the login or linking controller for the lifetime of its route.
class OtpDeliveryState with WidgetsBindingObserver {
  OtpDeliveryState(
    this.auth, {
    required this.active,
    required this.busy,
    required this.input,
    required this.onInputChanged,
  });
  final AuthClient auth;
  final TextEditingController input;
  final ValueChanged<String> onInputChanged;
  final bool Function() active, busy;
  final status = LxVar<OtpStatus?>(null);
  final remaining = LxVar(0);
  final retryable = LxVar(false);
  final phoneAvailable = LxVar(false);
  final testingAvailable = LxVar(false);
  final testCode = LxVar('');
  final revealing = LxVar(false);
  final revealFailed = LxVar(false);
  final expired = LxVar(false);
  int _revealGeneration = 0;
  bool _visible = true;
  bool get visible => _visible;
  bool get usesTestAutofill => auth.enableTestOtpInDebug && auth.testOtpEnabled;
  bool isTestAutofilled(String value) =>
      usesTestAutofill && testCode.value == value && value.isNotEmpty;

  void _writeInput(String value) {
    input.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    onInputChanged(value);
  }

  set visible(bool value) {
    if (value == _visible) return;
    _visible = value;
    if (value) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_closed && !_visible) clearTestCode();
      });
    } else {
      clearTestCode();
    }
  }

  bool get canReveal =>
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      !expired.value &&
      auth.testOtpEnabled &&
      testingAvailable.value &&
      active() &&
      visible &&
      !busy() &&
      status.value?.lifecycle == 'pending' &&
      status.value!.expiresAt >
          DateTime.now().millisecondsSinceEpoch + status.value!.clockOffset;
  void clearTestCode() {
    _revealGeneration++;
    if (isTestAutofilled(input.text)) _writeInput('');
    testCode('');
    revealing(false);
    revealFailed(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) clearTestCode();
  }

  Future<void> reveal() async {
    if (!canReveal || revealing.value) return;
    final challenge = auth.pendingChallenge;
    if (challenge == null) return;
    final generation = ++_revealGeneration;
    revealing(true);
    revealFailed(false);
    try {
      final code = await auth.revealTestOtp(challenge);
      if (_closed ||
          generation != _revealGeneration ||
          auth.pendingChallenge != challenge ||
          !canReveal) {
        return;
      }
      if (code != null &&
          code.expiresAt >
              DateTime.now().millisecondsSinceEpoch +
                  status.value!.clockOffset) {
        if (usesTestAutofill) {
          if (input.text.isNotEmpty) return;
          _writeInput(code.otp);
        }
        testCode(code.otp);
      } else {
        revealFailed(true);
      }
    } catch (_) {
      if (!_closed && generation == _revealGeneration) revealFailed(true);
    } finally {
      if (!_closed && generation == _revealGeneration) revealing(false);
    }
  }

  int _discoveryGeneration = 0;

  Future<void> _discoverTesting() async {
    if (!auth.testOtpEnabled) return;
    final generation = _discoveryGeneration;
    try {
      final available = await auth.testingOtpAvailable();
      if (!_closed && generation == _discoveryGeneration) {
        testingAvailable(available);
      }
    } catch (_) {
      /* Normal servers do not expose testing. */
    }
  }

  bool _polling = false, _closed = false;
  Timer? _timer;
  int _ticks = 0;
  bool get canResend =>
      status.value?.canResend == true && remaining.value == 0 && !busy();
  bool get canSms => canResend && status.value?.canSms == true;
  void start() {
    WidgetsBinding.instance.addObserver(this);
    discoverMethods();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      expired(
        status.value != null &&
            status.value!.expiresAt <=
                DateTime.now().millisecondsSinceEpoch +
                    status.value!.clockOffset,
      );
      if (!canReveal || busy()) clearTestCode();
      remaining(status.value?.secondsRemaining ?? auth.emailRetrySeconds);
      if (!active()) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (++_ticks % 3 == 0 &&
          visible &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        unawaited(poll());
      }
    });
  }

  /// Discover the active API's capabilities and discard outstanding discoveries.
  void discoverMethods() {
    _discoveryGeneration++;
    phoneAvailable(false);
    testingAvailable(false);
    unawaited(_discoverTesting());
    unawaited(loadMethods());
  }

  Future<void> loadMethods() async {
    final generation = _discoveryGeneration;
    try {
      final available = await auth.phoneAvailable();
      if (!_closed && generation == _discoveryGeneration) {
        phoneAvailable(available);
      }
    } catch (_) {
      if (!_closed && generation == _discoveryGeneration) phoneAvailable(false);
    }
  }

  void refresh() {
    if (_closed) return;
    if (status.value?.challenge != auth.primaryStatus?.challenge || !active()) {
      clearTestCode();
    }
    status(auth.primaryStatus);
    expired(
      status.value != null &&
          status.value!.expiresAt <=
              DateTime.now().millisecondsSinceEpoch + status.value!.clockOffset,
    );
    if (!canReveal) clearTestCode();
    retryable(auth.canRetryOtpRequest);
    remaining(status.value?.secondsRemaining ?? auth.emailRetrySeconds);
  }

  Future<void> poll() async {
    if (_closed || _polling || busy() || !active()) return;
    _polling = true;
    final challenge = auth.pendingChallenge;
    try {
      await auth.otpStatus();
      if (!_closed &&
          active() &&
          !busy() &&
          auth.pendingChallenge == challenge) {
        refresh();
        if (usesTestAutofill && visible && input.text.isEmpty) {
          if (!testingAvailable.value) await _discoverTesting();
          if (!_closed &&
              auth.pendingChallenge == challenge &&
              canReveal &&
              testCode.value.isEmpty)
            await reveal();
        }
      }
    } catch (_) {
      /* Keep the current challenge on an unavailable status request. */
    } finally {
      _polling = false;
    }
  }

  void close() {
    clearTestCode();
    WidgetsBinding.instance.removeObserver(this);
    _closed = true;
    _timer?.cancel();
    status.dispose();
    remaining.dispose();
    retryable.dispose();
    phoneAvailable.dispose();
    testingAvailable.dispose();
    testCode.dispose();
    revealing.dispose();
    revealFailed.dispose();
    expired.dispose();
  }
}
