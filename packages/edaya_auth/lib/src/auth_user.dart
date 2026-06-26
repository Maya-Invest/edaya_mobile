class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.image,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      image: json['image'] as String?,
    );
  }

  final String id;
  final String email;
  final String? name;
  final String? image;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    if (name != null) 'name': name,
    if (image != null) 'image': image,
  };
}
