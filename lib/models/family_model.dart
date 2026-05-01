class FamilyMemberModel {
  FamilyMemberModel({
    required this.email,
    required this.age,
    required this.role,
    required this.joinedAt,
    required this.permissions,
  });

  final String email;
  final String age;
  final String role;
  final String? joinedAt;
  final Map<String, bool> permissions;

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    final permissionsRaw = json['permissions'];
    final permissions = <String, bool>{
      'view_location': true,
      'view_events': true,
      'receive_alerts': true,
      'manage_geofence': false,
    };
    if (permissionsRaw is Map<String, dynamic>) {
      for (final key in permissions.keys) {
        final raw = permissionsRaw[key];
        if (raw is bool) {
          permissions[key] = raw;
        }
      }
    }

    return FamilyMemberModel(
      email: (json['email'] ?? '').toString(),
      age: (json['age'] ?? '').toString(),
      role: (json['role'] ?? 'member').toString(),
      joinedAt: json['joined_at']?.toString(),
      permissions: permissions,
    );
  }
}

class FamilyModel {
  FamilyModel({
    required this.familyId,
    required this.name,
    required this.title,
    required this.admin,
    required this.memberCount,
    required this.isAdmin,
    required this.members,
  });

  final String familyId;
  final String name;
  final String title;
  final String admin;
  final int memberCount;
  final bool isAdmin;
  final List<FamilyMemberModel> members;

  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    final membersJson = (json['members'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    return FamilyModel(
      familyId: (json['family_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      admin: (json['admin'] ?? '').toString(),
      memberCount: int.tryParse((json['member_count'] ?? 0).toString()) ?? 0,
      isAdmin: json['is_admin'] == true,
      members: membersJson.map(FamilyMemberModel.fromJson).toList(),
    );
  }
}
