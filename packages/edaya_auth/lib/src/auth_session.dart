import 'auth_user.dart';

class AuthSession {
  const AuthSession({required this.id, required this.userId, this.expiresAt});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      expiresAt: json['expiresAt'] as String?,
    );
  }

  final String id;
  final String userId;
  final String? expiresAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    if (expiresAt != null) 'expiresAt': expiresAt,
  };
}

class AuthSessionSnapshot {
  const AuthSessionSnapshot({required this.session, required this.user});

  factory AuthSessionSnapshot.fromJson(Map<String, dynamic> json) {
    return AuthSessionSnapshot(
      session: AuthSession.fromJson(
        Map<String, dynamic>.from(json['session'] as Map),
      ),
      user: AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }

  final AuthSession session;
  final AuthUser user;
}
