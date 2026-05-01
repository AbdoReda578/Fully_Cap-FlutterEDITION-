class CareLocationPoint {
  CareLocationPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final String? timestamp;

  factory CareLocationPoint.fromJson(Map<String, dynamic> json) {
    return CareLocationPoint(
      lat: double.tryParse((json['lat'] ?? 0).toString()) ?? 0,
      lng: double.tryParse((json['lng'] ?? 0).toString()) ?? 0,
      timestamp: json['timestamp']?.toString(),
    );
  }
}

Map<String, bool> _parseCarePermissions(dynamic raw) {
  final out = <String, bool>{
    'view_location': true,
    'view_events': true,
    'receive_alerts': true,
    'manage_geofence': false,
  };
  if (raw is Map<String, dynamic>) {
    for (final key in out.keys) {
      final value = raw[key];
      if (value is bool) {
        out[key] = value;
      }
    }
  }
  return out;
}

class CarePatientSummary {
  CarePatientSummary({
    required this.patientEmail,
    required this.displayName,
    required this.isOnline,
    required this.lastUpdateAt,
    required this.lastSeenAt,
    required this.lastLocation,
    required this.permissions,
  });

  final String patientEmail;
  final String displayName;
  final bool isOnline;
  final String? lastUpdateAt;
  final String? lastSeenAt;
  final CareLocationPoint? lastLocation;
  final Map<String, bool> permissions;

  factory CarePatientSummary.fromJson(Map<String, dynamic> json) {
    return CarePatientSummary(
      patientEmail: (json['patient_email'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      isOnline: json['is_online'] == true,
      lastUpdateAt: json['last_update_at']?.toString(),
      lastSeenAt: json['last_seen_at']?.toString(),
      lastLocation: json['last_location'] is Map<String, dynamic>
          ? CareLocationPoint.fromJson(
              json['last_location'] as Map<String, dynamic>,
            )
          : null,
      permissions: _parseCarePermissions(json['permissions']),
    );
  }
}

class CarePatientStats {
  CarePatientStats({
    required this.takenToday,
    required this.takenWeek,
    required this.alertsToday,
    required this.alertsWeek,
    required this.lastMovementAt,
    required this.timeOutsideSafeZoneMinutes,
  });

  final int takenToday;
  final int takenWeek;
  final int alertsToday;
  final int alertsWeek;
  final String? lastMovementAt;
  final int timeOutsideSafeZoneMinutes;

  factory CarePatientStats.fromJson(Map<String, dynamic> json) {
    return CarePatientStats(
      takenToday: int.tryParse((json['taken_today'] ?? 0).toString()) ?? 0,
      takenWeek: int.tryParse((json['taken_week'] ?? 0).toString()) ?? 0,
      alertsToday: int.tryParse((json['alerts_today'] ?? 0).toString()) ?? 0,
      alertsWeek: int.tryParse((json['alerts_week'] ?? 0).toString()) ?? 0,
      lastMovementAt: json['last_movement_at']?.toString(),
      timeOutsideSafeZoneMinutes:
          int.tryParse(
            (json['time_outside_safe_zone_minutes'] ?? 0).toString(),
          ) ??
          0,
    );
  }
}

class CareEventItem {
  CareEventItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.severity,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String timestamp;
  final String severity;
  final double? lat;
  final double? lng;

  factory CareEventItem.fromJson(Map<String, dynamic> json) {
    return CareEventItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
      severity: (json['severity'] ?? 'info').toString(),
      lat: json['lat'] == null
          ? null
          : double.tryParse(json['lat'].toString()),
      lng: json['lng'] == null
          ? null
          : double.tryParse(json['lng'].toString()),
    );
  }
}

class CarePatientDashboard {
  CarePatientDashboard({
    required this.patientEmail,
    required this.isOnline,
    required this.lastSeenAt,
    required this.lastUpdateAt,
    required this.safeZone,
    required this.lastLocation,
    required this.path,
    required this.stats,
    required this.recentEvents,
    required this.permissions,
  });

  final String patientEmail;
  final bool isOnline;
  final String? lastSeenAt;
  final String? lastUpdateAt;
  final Map<String, dynamic>? safeZone;
  final CareLocationPoint? lastLocation;
  final List<CareLocationPoint> path;
  final CarePatientStats stats;
  final List<CareEventItem> recentEvents;
  final Map<String, bool> permissions;

  factory CarePatientDashboard.fromJson(Map<String, dynamic> json) {
    final pathRaw = (json['path'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    final eventsRaw = (json['recent_events'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    return CarePatientDashboard(
      patientEmail: (json['patient_email'] ?? '').toString(),
      isOnline: json['is_online'] == true,
      lastSeenAt: json['last_seen_at']?.toString(),
      lastUpdateAt: json['last_update_at']?.toString(),
      safeZone: json['safe_zone'] is Map<String, dynamic>
          ? json['safe_zone'] as Map<String, dynamic>
          : null,
      lastLocation: json['last_location'] is Map<String, dynamic>
          ? CareLocationPoint.fromJson(
              json['last_location'] as Map<String, dynamic>,
            )
          : null,
      path: pathRaw.map(CareLocationPoint.fromJson).toList(),
      stats: CarePatientStats.fromJson(
        json['stats'] is Map<String, dynamic>
            ? json['stats'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      recentEvents: eventsRaw.map(CareEventItem.fromJson).toList(),
      permissions: _parseCarePermissions(json['permissions']),
    );
  }
}
