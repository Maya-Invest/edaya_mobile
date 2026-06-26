class AuthError {
  const AuthError({required this.message, this.code});

  factory AuthError.fromJson(Map<String, dynamic> json) {
    return AuthError(
      message: json['message'] as String? ?? 'Authentication failed',
      code: json['code'] as String?,
    );
  }

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$code: $message';
}
