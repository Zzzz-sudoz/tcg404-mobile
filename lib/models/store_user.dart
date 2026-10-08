class StoreUser {
  const StoreUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
  final String id, name, email, role;

  factory StoreUser.fromJson(Map<String, dynamic> json) {
    for (final key in ['id', 'name', 'email', 'role']) {
      if (json[key] is! String || (json[key] as String).trim().isEmpty) {
        throw const FormatException('Account response is invalid.');
      }
    }
    return StoreUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}
