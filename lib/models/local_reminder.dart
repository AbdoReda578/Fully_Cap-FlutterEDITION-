import 'reminder_model.dart';

/// Local/offline representation of a reminder.
///
/// Notes:
/// - `localId` is stable and used for notification payloads and offline queues.
/// - `serverId` is the backend id once synced (may be null while offline).
class LocalReminder {
  LocalReminder({
    required this.localId,
    this.serverId,
    required this.userEmail,
    required this.medName,
    required this.dose,
    required this.time,
    List<String>? times,
    required this.notificationType,
    required this.selectedFamilyMembers,
    required this.singleFamilyMember,
    required this.emailNotifications,
    required this.calendarSync,
    this.createdAt,
    required this.repeatingNotificationId,
    List<int>? repeatingNotificationIds,
    this.snoozeNotificationId,
    this.snoozedUntil,
    this.pendingCreate = false,
    this.pendingDelete = false,
    this.isDeleted = false,
  }) : times = _normalizeTimes(times, fallback: time),
       repeatingNotificationIds = _normalizeNotificationIds(
         repeatingNotificationIds,
         fallback: repeatingNotificationId,
       );

  final String localId;
  final String? serverId;
  final String userEmail;
  final String medName;
  final String dose;
  final String time; // HH:MM (24h)
  final List<String> times; // HH:MM list (24h)
  final String notificationType;
  final List<String> selectedFamilyMembers;
  final String singleFamilyMember;
  final bool emailNotifications;
  final bool calendarSync;
  final String? createdAt;

  final int repeatingNotificationId;
  final List<int> repeatingNotificationIds;
  final int? snoozeNotificationId;
  final DateTime? snoozedUntil;

  final bool pendingCreate;
  final bool pendingDelete;
  final bool isDeleted;

  bool get isActive => !isDeleted && !pendingDelete;

  ReminderModel toReminderModel() {
    return ReminderModel(
      id: localId,
      userEmail: userEmail,
      medName: medName,
      dose: dose,
      time: time,
      times: List<String>.from(times),
      notificationType: notificationType,
      selectedFamilyMembers: List<String>.from(selectedFamilyMembers),
      emailNotifications: emailNotifications,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'local_id': localId,
      'server_id': serverId,
      'user_email': userEmail,
      'med_name': medName,
      'dose': dose,
      'time': time,
      'times': times,
      'notification_type': notificationType,
      'selected_family_members': selectedFamilyMembers,
      'single_family_member': singleFamilyMember,
      'email_notifications': emailNotifications,
      'calendar_sync': calendarSync,
      'created_at': createdAt,
      'repeating_notification_id': repeatingNotificationId,
      'repeating_notification_ids': repeatingNotificationIds,
      'snooze_notification_id': snoozeNotificationId,
      'snoozed_until': snoozedUntil?.toIso8601String(),
      'pending_create': pendingCreate,
      'pending_delete': pendingDelete,
      'is_deleted': isDeleted,
    };
  }

  factory LocalReminder.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['selected_family_members'];
    final members = rawMembers is List
        ? rawMembers
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    DateTime? snoozedUntil;
    final rawSnoozedUntil = json['snoozed_until'];
    if (rawSnoozedUntil is String && rawSnoozedUntil.isNotEmpty) {
      snoozedUntil = DateTime.tryParse(rawSnoozedUntil);
    }

    final time = (json['time'] ?? '').toString();
    final times = _normalizeTimes(json['times'], fallback: time);

    final rawRepeatingIds = json['repeating_notification_ids'];
    final repeatingIds = rawRepeatingIds is List
        ? rawRepeatingIds
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList()
        : <int>[];
    final repeatingIdLegacy =
        int.tryParse((json['repeating_notification_id'] ?? 0).toString()) ?? 0;
    final repeatingId = repeatingIds.isNotEmpty
        ? repeatingIds.first
        : repeatingIdLegacy;

    return LocalReminder(
      localId: (json['local_id'] ?? '').toString(),
      serverId: (json['server_id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['server_id'] ?? '').toString(),
      userEmail: (json['user_email'] ?? '').toString(),
      medName: (json['med_name'] ?? '').toString(),
      dose: (json['dose'] ?? '').toString(),
      time: times.isNotEmpty ? times.first : time,
      times: times,
      notificationType: (json['notification_type'] ?? 'self').toString(),
      selectedFamilyMembers: members,
      singleFamilyMember: (json['single_family_member'] ?? '').toString(),
      emailNotifications: json['email_notifications'] == true,
      calendarSync: json['calendar_sync'] == true,
      createdAt: json['created_at']?.toString(),
      repeatingNotificationId: repeatingId,
      repeatingNotificationIds: repeatingIds,
      snoozeNotificationId:
          (json['snooze_notification_id'] == null ||
                  (json['snooze_notification_id'] ?? '').toString().isEmpty)
              ? null
              : int.tryParse((json['snooze_notification_id'] ?? '').toString()),
      snoozedUntil: snoozedUntil,
      pendingCreate: json['pending_create'] == true,
      pendingDelete: json['pending_delete'] == true,
      isDeleted: json['is_deleted'] == true,
    );
  }

  LocalReminder copyWith({
    String? serverId,
    String? userEmail,
    String? medName,
    String? dose,
    String? time,
    List<String>? times,
    String? notificationType,
    List<String>? selectedFamilyMembers,
    String? singleFamilyMember,
    bool? emailNotifications,
    bool? calendarSync,
    String? createdAt,
    int? repeatingNotificationId,
    List<int>? repeatingNotificationIds,
    int? snoozeNotificationId,
    DateTime? snoozedUntil,
    bool? pendingCreate,
    bool? pendingDelete,
    bool? isDeleted,
  }) {
    final nextTimes = times ?? List<String>.from(this.times);
    final nextTime = (time ?? (nextTimes.isNotEmpty ? nextTimes.first : this.time))
        .trim();
    final nextRepeatingIds =
        repeatingNotificationIds ?? List<int>.from(this.repeatingNotificationIds);
    final nextRepeatingId = repeatingNotificationId ??
        (nextRepeatingIds.isNotEmpty
            ? nextRepeatingIds.first
            : this.repeatingNotificationId);

    return LocalReminder(
      localId: localId,
      serverId: serverId ?? this.serverId,
      userEmail: userEmail ?? this.userEmail,
      medName: medName ?? this.medName,
      dose: dose ?? this.dose,
      time: nextTime,
      times: nextTimes,
      notificationType: notificationType ?? this.notificationType,
      selectedFamilyMembers:
          selectedFamilyMembers ?? List<String>.from(this.selectedFamilyMembers),
      singleFamilyMember: singleFamilyMember ?? this.singleFamilyMember,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      calendarSync: calendarSync ?? this.calendarSync,
      createdAt: createdAt ?? this.createdAt,
      repeatingNotificationId: nextRepeatingId,
      repeatingNotificationIds: nextRepeatingIds,
      snoozeNotificationId: snoozeNotificationId ?? this.snoozeNotificationId,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      pendingCreate: pendingCreate ?? this.pendingCreate,
      pendingDelete: pendingDelete ?? this.pendingDelete,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  static List<String> _normalizeTimes(dynamic raw, {required String fallback}) {
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

  static List<int> _normalizeNotificationIds(dynamic raw, {required int fallback}) {
    final values = raw is List ? raw : <dynamic>[fallback];
    final out = <int>[];
    final seen = <int>{};
    for (final item in values) {
      final id = int.tryParse(item.toString()) ?? 0;
      if (id <= 0 || !seen.add(id)) {
        continue;
      }
      out.add(id);
    }
    if (out.isNotEmpty) {
      return out;
    }
    return fallback > 0 ? <int>[fallback] : <int>[];
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
