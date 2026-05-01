class ReminderModel {
  ReminderModel({
    required this.id,
    required this.userEmail,
    required this.medName,
    required this.dose,
    required this.time,
    required this.times,
    required this.notificationType,
    required this.selectedFamilyMembers,
    required this.emailNotifications,
    required this.createdAt,
  });

  final String id;
  final String userEmail;
  final String medName;
  final String dose;
  final String time;
  final List<String> times;
  final String notificationType;
  final List<String> selectedFamilyMembers;
  final bool emailNotifications;
  final String? createdAt;

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['selected_family_members'];
    final selectedMembers = rawMembers is List
        ? rawMembers
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    final time = (json['time'] ?? '').toString();
    final times = _parseTimes(json['times'], fallback: time);

    return ReminderModel(
      id: (json['id'] ?? '').toString(),
      userEmail: (json['user_email'] ?? '').toString(),
      medName: (json['med_name'] ?? '').toString(),
      dose: (json['dose'] ?? '').toString(),
      time: times.isNotEmpty ? times.first : time,
      times: times,
      notificationType: (json['notification_type'] ?? 'self').toString(),
      selectedFamilyMembers: selectedMembers,
      emailNotifications: json['email_notifications'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }

  static List<String> _parseTimes(dynamic raw, {required String fallback}) {
    final values = raw is List ? raw : <dynamic>[fallback];
    final out = <String>[];
    final seen = <String>{};
    for (final item in values) {
      final value = item.toString().trim();
      if (!_isValidTime(value)) {
        continue;
      }
      if (seen.add(value)) {
        out.add(value);
      }
    }
    if (out.isNotEmpty) {
      return out;
    }
    return _isValidTime(fallback) ? <String>[fallback] : <String>[];
  }

  static bool _isValidTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return false;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }
}

class DueReminderModel {
  DueReminderModel({
    required this.id,
    required this.medName,
    required this.dose,
    required this.time,
    required this.times,
    required this.forUser,
  });

  final String id;
  final String medName;
  final String dose;
  final String time;
  final List<String> times;
  final String forUser;

  factory DueReminderModel.fromJson(Map<String, dynamic> json) {
    final time = (json['time'] ?? '').toString();
    return DueReminderModel(
      id: (json['id'] ?? '').toString(),
      medName: (json['med_name'] ?? '').toString(),
      dose: (json['dose'] ?? '').toString(),
      time: time,
      times: ReminderModel._parseTimes(json['times'], fallback: time),
      forUser: (json['for_user'] ?? '').toString(),
    );
  }
}
