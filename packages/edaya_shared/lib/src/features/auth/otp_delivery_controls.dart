import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../l10n/l10n_extension.dart';
import 'otp_delivery_state.dart';

/// Delivery guidance and user-triggered replacements shared by login and linking.
class OtpDeliveryControls extends StatelessWidget {
  const OtpDeliveryControls({
    super.key,
    required this.state,
    required this.onResend,
    required this.onSms,
    required this.onRetry,
  });
  final OtpDeliveryState state;
  final VoidCallback onResend, onSms, onRetry;
  @override
  Widget build(BuildContext context) {
    state.visible =
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        TickerMode.valuesOf(context).enabled;
    return LWatch(() {
      final status = state.status.value;
      if (status == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (AuthClient.testOtpAccess && state.canReveal) ...[
            Text(context.tr.testingOnly),
            OutlinedButton(
              key: const Key('auth-test-reveal'),
              onPressed: state.revealing.value ? null : () => state.reveal(),
              child: Text(context.tr.showTestCode),
            ),
            if (state.testCode.value.isNotEmpty)
              Row(
                children: [
                  Text(state.testCode.value, key: const Key('auth-test-code')),
                  TextButton(
                    key: const Key('auth-test-copy'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: state.testCode.value),
                      );
                    },
                    child: Text(context.tr.copyTestCode),
                  ),
                ],
              ),
            if (state.revealFailed.value) Text(context.tr.testCodeUnavailable),
          ],
          if (state.retryable.value)
            TextButton(
              key: const Key('auth-retry'),
              onPressed: state.busy() ? null : onRetry,
              child: Text(context.tr.retryRequest),
            ),
          const SizedBox(height: 12),
          Text(
            status.channel == 'whatsapp'
                ? context.tr.checkWhatsApp
                : status.channel == 'sms'
                ? context.tr.checkSms
                : context.tr.checkEmailCode,
          ),
          Text(context.tr.useMostRecentCode),
          if (status.delivery == 'failed') Text(context.tr.codeDeliveryFailed),
          if (status.delivery == 'uncertain')
            Text(context.tr.codeDeliveryUncertain),
          if (status.lifecycle == 'expired') Text(context.tr.codeExpired),
          if (state.remaining.value > 0)
            Text(context.tr.resendCountdown(state.remaining.value)),
          TextButton(
            key: const Key('auth-resend'),
            onPressed: state.canResend ? onResend : null,
            child: Text(context.tr.resendCodeButton),
          ),
          if (status.canSms)
            TextButton(
              key: const Key('auth-sms'),
              onPressed: state.canSms ? onSms : null,
              child: Text(context.tr.sendBySms),
            ),
        ],
      );
    });
  }
}
