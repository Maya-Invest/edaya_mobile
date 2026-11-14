import 'dart:async';
import 'dart:convert';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/src/features/auth/otp_delivery_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'debug polling pulls a pending code once and only while visible',
    () async {
      var pulls = 0;
      var discoveryAttempts = 0;
      final expires = DateTime.now().millisecondsSinceEpoch + 300000;
      final status = {
        'challenge': 'current',
        'lifecycle': 'pending',
        'expiresAt': expires,
      };
      final auth =
          AuthClient(
              baseUrl: 'http://localhost:9999',
              enableTestOtpInDebug: true,
              client: MockClient((request) async {
                final path = request.url.path;
                if (path.endsWith('/otp/status'))
                  return http.Response(jsonEncode(status), 200);
                if (path.endsWith('/capabilities')) {
                  if (++discoveryAttempts == 1) {
                    return http.Response('{}', 503);
                  }
                  return http.Response('{"otpAccess":true}', 200);
                }
                expect(path.endsWith('/testing/otp'), isTrue);
                pulls++;
                return http.Response(
                  jsonEncode({
                    'challenge': 'current',
                    'otp': '123456',
                    'channel': 'email',
                    'expiresAt': expires,
                  }),
                  200,
                );
              }),
            )
            ..pendingChallenge = 'current'
            ..pendingStep = 'primary_required';
      final input = TextEditingController();
      var submittedValue = '';
      addTearDown(input.dispose);
      final state = OtpDeliveryState(
        auth,
        input: input,
        onInputChanged: (value) => submittedValue = value,
        active: () => true,
        busy: () => false,
      );
      addTearDown(state.close);
      state.visible = false;
      await state.poll();
      expect(pulls, 0);
      state.visible = true;
      await state.poll();
      expect(pulls, 0);
      await state.poll();
      await state.poll();
      expect(pulls, auth.testOtpEnabled ? 1 : 0);
      expect(input.text.isNotEmpty, auth.testOtpEnabled);
      expect(input.text == submittedValue, isTrue);
      input.text = 'manual';
      await state.poll();
      expect(input.text, 'manual');
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(input.text, 'manual');
    },
  );
  test(
    'test codes are explicit, transient, and discard stale lookups',
    () async {
      final responses = <Completer<http.Response>>[];
      var discovery = 0;
      final auth = AuthClient(
        baseUrl: 'http://localhost:9999',
        enableTestOtpInDebug: true,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/capabilities')) {
            discovery++;
            return http.Response('{"otpAccess":true}', 200);
          }
          final response = Completer<http.Response>();
          responses.add(response);
          return response.future;
        }),
      );
      var active = true;
      final input = TextEditingController();
      var submittedValue = '';
      addTearDown(input.dispose);
      final state = OtpDeliveryState(
        auth,
        input: input,
        onInputChanged: (value) => submittedValue = value,
        active: () => active,
        busy: () => false,
      );
      addTearDown(state.close);
      const expected =
          !bool.fromEnvironment('dart.vm.product') &&
          !bool.fromEnvironment('dart.vm.profile') &&
          bool.fromEnvironment('TEST_OTP_ACCESS', defaultValue: true);
      expect(auth.testOtpEnabled, expected);
      if (!expected) {
        expect(await auth.testingOtpAvailable(), isFalse);
        await state.reveal();
        expect(discovery, 0);
        expect(responses, isEmpty);
        expect(state.canReveal, isFalse);
        return;
      }
      expect(await auth.testingOtpAvailable(), isTrue);
      expect(await auth.testingOtpAvailable(), isTrue);
      expect(discovery, 1);
      state.testingAvailable(true);
      void challenge(
        String id, {
        String lifecycle = 'pending',
        int? expiresAt,
      }) {
        auth.pendingChallenge = id;
        auth.pendingStep = 'primary_required';
        auth.primaryStatus = OtpStatus.fromJson({
          'challenge': id,
          'lifecycle': lifecycle,
          'expiresAt':
              expiresAt ?? DateTime.now().millisecondsSinceEpoch + 300000,
        });
        state.refresh();
      }

      http.Response code(String id) => http.Response(
        jsonEncode({
          'challenge': id,
          'otp': '123456',
          'channel': 'email',
          'expiresAt': DateTime.now().millisecondsSinceEpoch + 300000,
        }),
        200,
      );
      Future<void> started() async {
        while (responses.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      challenge('old');
      expect(state.testCode.value, isEmpty);
      var pending = state.reveal();
      await started();
      challenge('replacement');
      responses.removeAt(0).complete(code('old'));
      await pending;
      expect(state.testCode.value, isEmpty);
      pending = state.reveal();
      await started();
      responses.removeAt(0).complete(code('replacement'));
      await pending;
      expect(state.testCode.value.isNotEmpty, isTrue);
      expect(input.text.isNotEmpty && input.text == submittedValue, isTrue);
      expect(auth.renewalCredential, isNull);
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(state.testCode.value, isEmpty);
      expect(input.text.isEmpty && submittedValue.isEmpty, isTrue);
      pending = state.reveal();
      await started();
      state.visible = false;
      responses.removeAt(0).complete(code('replacement'));
      await pending;
      expect(state.testCode.value, isEmpty);
      state.visible = true;
      pending = state.reveal();
      await started();
      input.text = 'manual';
      responses.removeAt(0).complete(code('replacement'));
      await pending;
      expect(input.text, 'manual');
      expect(state.testCode.value.isEmpty, isTrue);
      for (final lifecycle in [
        'completed',
        'superseded',
        'exhausted',
        'expired',
      ]) {
        challenge('replacement', lifecycle: lifecycle);
        expect(state.canReveal, isFalse);
        await state.reveal();
        expect(responses, isEmpty);
      }
      challenge(
        'replacement',
        expiresAt: DateTime.now().millisecondsSinceEpoch - 1,
      );
      expect(state.canReveal, isFalse);
      challenge('replacement');
      state.testCode('123456');
      active = false;
      state.refresh();
      expect(state.testCode.value, isEmpty);
    },
  );
}
