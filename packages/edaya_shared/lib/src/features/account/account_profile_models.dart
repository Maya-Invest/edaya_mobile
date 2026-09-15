class AccountContactProfile {
  const AccountContactProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.photoUrl,
    this.hasAccess = true,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool hasAccess;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty && last.isEmpty) {
      return '?';
    }
    if (last.isEmpty) {
      return first.substring(0, 1).toUpperCase();
    }
    return '${first.substring(0, 1)}${last.substring(0, 1)}'.toUpperCase();
  }

  AccountContactProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? photoUrl,
    bool? hasAccess,
  }) {
    return AccountContactProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      hasAccess: hasAccess ?? this.hasAccess,
    );
  }
}
