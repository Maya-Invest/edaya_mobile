import 'package:edaya_auth/edaya_auth.dart';

import '../../l10n/l10n_lookup.dart';

String localizedAuthError(AuthError? error, String fallback) {
  final invalidCode = const {
    'invalid_code',
    'invalid_otp',
    'otp_expired',
    'invalid_credentials',
  }.contains(error?.code);
  if (invalidCode ||
      error?.message == 'Invalid or expired verification code.') {
    return systemL10n().verificationInvalid;
  }
  return fallback;
}
