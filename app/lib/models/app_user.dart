class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.consentAcceptedAt,
  });

  final int id;
  final String name;
  final String phone;
  final String role;
  final DateTime? consentAcceptedAt;

  bool get isSenior => role == 'senior';
  bool get isNominee => role == 'nominee';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final consent = json['consent_accepted_at'] as String?;
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      consentAcceptedAt: consent == null ? null : DateTime.parse(consent),
    );
  }
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['access_token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}