/// A normalized email or international phone number for passwordless login.
/// Phone country support is enforced by the authentication service.
class LoginIdentifier {
  const LoginIdentifier._(this.kind, this.value);
  final String kind;
  final String value;

  /// Matches the authentication service's normalization and validation rules.
  /// Returns null for invalid contacts; phone numbers require a country code.
  static LoginIdentifier? detect(String input) {
    final email = input.trim().toLowerCase();
    if (email.length <= 254 &&
        RegExp(r'^[^\s@]+@[^\s@][^\s.@]*\.[^\s@]+$').hasMatch(email)) {
      return LoginIdentifier._('email', email);
    }
    final phone = input.trim().replaceAll(RegExp(r'[ ().-]'), '');
    if (RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone)) {
      return LoginIdentifier._('phone', phone);
    }
    return null;
  }
}
