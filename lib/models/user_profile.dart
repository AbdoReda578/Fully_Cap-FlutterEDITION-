class ProfileActivityItem {
  ProfileActivityItem({
    required this.type,
    required this.medName,
    required this.timestampIso,
  });

  final String type; // taken / snooze / dismiss / no_response
  final String medName;
  final String timestampIso;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'med_name': medName,
      'timestamp': timestampIso,
    };
  }

  factory ProfileActivityItem.fromJson(Map<String, dynamic> json) {
    return ProfileActivityItem(
      type: (json['type'] ?? '').toString(),
      medName: (json['med_name'] ?? '').toString(),
      timestampIso: (json['timestamp'] ?? '').toString(),
    );
  }
}

class UserProfile {
  UserProfile({
    required this.email,
    required this.displayName,
    required this.title,
    required this.updatedAt,
    required this.avatarImageBase64,
    required this.tags,
    required this.avatarSeed,
    required this.dailyGoalTaken,
    required this.totalTaken,
    required this.totalSnoozed,
    required this.totalDismissed,
    required this.totalNoResponse,
    required this.currentStreakDays,
    required this.bestStreakDays,
    this.lastTakenDateIso,
    required this.activities,
    required this.unlockedTitleIds,
    required this.unlockedFrameIds,
    required this.activeFrameId,
  });

  final String email;
  final String displayName;
  final String title;
  final String updatedAt;
  final String? avatarImageBase64;

  final List<String> tags;
  final int avatarSeed;
  final int dailyGoalTaken;

  final int totalTaken;
  final int totalSnoozed;
  final int totalDismissed;
  final int totalNoResponse;

  final int currentStreakDays;
  final int bestStreakDays;
  final String? lastTakenDateIso;

  final List<ProfileActivityItem> activities;
  final List<String> unlockedTitleIds;
  final List<String> unlockedFrameIds;
  final String activeFrameId;

  int get totalActions =>
      totalTaken + totalSnoozed + totalDismissed + totalNoResponse;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'display_name': displayName,
      'title': title,
      'updated_at': updatedAt,
      'avatar_image_base64': avatarImageBase64,
      'tags': tags,
      'avatar_seed': avatarSeed,
      'daily_goal_taken': dailyGoalTaken,
      'total_taken': totalTaken,
      'total_snoozed': totalSnoozed,
      'total_dismissed': totalDismissed,
      'total_no_response': totalNoResponse,
      'current_streak_days': currentStreakDays,
      'best_streak_days': bestStreakDays,
      'last_taken_date': lastTakenDateIso,
      'activities': activities.map((e) => e.toJson()).toList(),
      'unlocked_titles': unlockedTitleIds,
      'unlocked_frames': unlockedFrameIds,
      'active_frame_id': activeFrameId,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
        : <String>[];

    final rawActivities = json['activities'];
    final activities = rawActivities is List
        ? rawActivities
              .whereType<Map>()
              .map((e) => ProfileActivityItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <ProfileActivityItem>[];

    final rawUnlockedTitles = json['unlocked_titles'];
    final unlockedTitleIds = rawUnlockedTitles is List
        ? rawUnlockedTitles
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toSet()
              .toList()
        : <String>[];

    final rawUnlockedFrames = json['unlocked_frames'];
    final unlockedFrameIds = rawUnlockedFrames is List
        ? rawUnlockedFrames
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toSet()
              .toList()
        : <String>[];

    final rawAvatarImage = (json['avatar_image_base64'] ?? '').toString().trim();
    final avatarImageBase64 = rawAvatarImage.isEmpty ? null : rawAvatarImage;

    final activeFrameRaw = (json['active_frame_id'] ?? '').toString().trim();
    final activeFrameId = activeFrameRaw.isEmpty ? 'classic' : activeFrameRaw;

    return UserProfile(
      email: (json['email'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      avatarImageBase64: avatarImageBase64,
      tags: tags,
      avatarSeed: int.tryParse((json['avatar_seed'] ?? 1).toString()) ?? 1,
      dailyGoalTaken:
          int.tryParse((json['daily_goal_taken'] ?? 2).toString()) ?? 2,
      totalTaken: int.tryParse((json['total_taken'] ?? 0).toString()) ?? 0,
      totalSnoozed: int.tryParse((json['total_snoozed'] ?? 0).toString()) ?? 0,
      totalDismissed:
          int.tryParse((json['total_dismissed'] ?? 0).toString()) ?? 0,
      totalNoResponse:
          int.tryParse((json['total_no_response'] ?? 0).toString()) ?? 0,
      currentStreakDays:
          int.tryParse((json['current_streak_days'] ?? 0).toString()) ?? 0,
      bestStreakDays:
          int.tryParse((json['best_streak_days'] ?? 0).toString()) ?? 0,
      lastTakenDateIso: (json['last_taken_date'] ?? '').toString().trim().isEmpty
          ? null
          : (json['last_taken_date'] ?? '').toString(),
      activities: activities,
      unlockedTitleIds: unlockedTitleIds,
      unlockedFrameIds: unlockedFrameIds,
      activeFrameId: activeFrameId,
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? title,
    String? updatedAt,
    String? avatarImageBase64,
    List<String>? tags,
    int? avatarSeed,
    int? dailyGoalTaken,
    int? totalTaken,
    int? totalSnoozed,
    int? totalDismissed,
    int? totalNoResponse,
    int? currentStreakDays,
    int? bestStreakDays,
    String? lastTakenDateIso,
    List<ProfileActivityItem>? activities,
    List<String>? unlockedTitleIds,
    List<String>? unlockedFrameIds,
    String? activeFrameId,
  }) {
    return UserProfile(
      email: email,
      displayName: displayName ?? this.displayName,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarImageBase64: avatarImageBase64 ?? this.avatarImageBase64,
      tags: tags ?? List<String>.from(this.tags),
      avatarSeed: avatarSeed ?? this.avatarSeed,
      dailyGoalTaken: dailyGoalTaken ?? this.dailyGoalTaken,
      totalTaken: totalTaken ?? this.totalTaken,
      totalSnoozed: totalSnoozed ?? this.totalSnoozed,
      totalDismissed: totalDismissed ?? this.totalDismissed,
      totalNoResponse: totalNoResponse ?? this.totalNoResponse,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      bestStreakDays: bestStreakDays ?? this.bestStreakDays,
      lastTakenDateIso: lastTakenDateIso ?? this.lastTakenDateIso,
      activities: activities ?? List<ProfileActivityItem>.from(this.activities),
      unlockedTitleIds:
          unlockedTitleIds ?? List<String>.from(this.unlockedTitleIds),
      unlockedFrameIds:
          unlockedFrameIds ?? List<String>.from(this.unlockedFrameIds),
      activeFrameId: activeFrameId ?? this.activeFrameId,
    );
  }
}
