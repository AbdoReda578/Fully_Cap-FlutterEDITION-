class UserModel {
  UserModel({
    required this.email,
    required this.age,
    required this.familyId,
    required this.role,
    required this.lastSeenAt,
    required this.safeZone,
  });

  final String email;
  final String age;
  final String? familyId;
  final String role;
  final String? lastSeenAt;
  final Map<String, dynamic>? safeZone;

  bool get isPatient => role == 'patient';
  bool get isFamily => role == 'family';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] ?? '').toString().trim().toLowerCase();
    return UserModel(
      email: (json['email'] ?? '').toString(),
      age: (json['age'] ?? '').toString(),
      familyId: json['family_id']?.toString(),
      role: rawRole == 'family' ? 'family' : 'patient',
      lastSeenAt: json['last_seen_at']?.toString(),
      safeZone: json['safe_zone'] is Map<String, dynamic>
          ? json['safe_zone'] as Map<String, dynamic>
          : null,
    );
  }
}
