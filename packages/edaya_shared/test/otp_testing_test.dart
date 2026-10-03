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
    'test codes are explicit, transient, and discard stale lookups',
    () async {
      final responses = <Completer<http.Response>>[];
      var discovery = 0;
      final auth = AuthClient(
        baseUrl: 'http://localhost:9999',
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
      final state = OtpDeliveryState(
        auth,
        active: () => active,
        busy: () => false,
      );
      addTearDown(state.close);
      if (!AuthClient.testOtpAccess) {
        expect(await auth.testingOtpAvailable(), isFalse);
        await state.reveal();
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
      expect(auth.renewalCredential, isNull);
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(state.testCode.value, isEmpty);
      pending = state.reveal();
      await started();
      state.visible = false;
      responses.removeAt(0).complete(code('replacement'));
      await pending;
      expect(state.testCode.value, isEmpty);
      state.visible = true;
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
