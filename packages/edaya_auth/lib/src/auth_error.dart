class AuthError {
  const AuthError({required this.message, this.code});

  factory AuthError.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'] as String? ?? 'Authentication failed';
    return AuthError(
      message: normalizeAuthErrorMessage(rawMessage),
      code: json['code'] as String?,
    );
  }

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$code: $message';
}

/// Maps low-level API/runtime failures to user-facing sign-in messages.
String normalizeAuthErrorMessage(String message) {
  final trimmed = message.trim();
  final lower = trimmed.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');

  if (trimmed.contains('Aborted()') || trimmed.contains('ASSERTIONS')) {
    return 'Sign-in failed. For local dev, run `bun repo seed` in edaya_backend.';
  }

  if (lower.contains('invalid otp') ||
      lower.contains('invalid code') ||
      lower.contains('otp expired') ||
      lower.contains('invalid credentials')) {
    return 'Invalid or expired verification code.';
  }

  return trimmed.isEmpty ? 'Authentication failed' : trimmed;
}
