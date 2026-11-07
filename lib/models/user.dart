class AppUser {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String username;
  final String phone;
  final DateTime birthDate;
  final bool isAdmin;

  const AppUser({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.username,
    required this.phone,
    required this.birthDate,
    this.isAdmin = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      phone: json['phone'] as String,
      birthDate: DateTime.parse(
        (json['birthDate'] ?? json['birth_date']) as String,
      ),
      isAdmin: json['isAdmin'] as bool? ?? json['role'] == 'admin',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'username': username,
      'phone': phone,
      'birthDate': birthDate.toIso8601String(),
      'isAdmin': isAdmin,
    };
  }
}
