class QueuedSyncItem {
  QueuedSyncItem({
    required this.id,
    required this.type,
    required this.enqueuedAt,
    required this.payload,
  });

  final String id;

  /// One of:
  /// - reminder_create
  /// - reminder_delete
  /// - reminder_action
  /// - reminder_escalate
  final String type;

  final DateTime enqueuedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'enqueued_at': enqueuedAt.toIso8601String(),
      'payload': payload,
    };
  }

  factory QueuedSyncItem.fromJson(Map<String, dynamic> json) {
    final payloadJson = json['payload'];
    final payload = payloadJson is Map<String, dynamic>
        ? payloadJson
        : <String, dynamic>{};

    final enqueuedAtRaw = (json['enqueued_at'] ?? '').toString();
    final parsedAt = DateTime.tryParse(enqueuedAtRaw);

    return QueuedSyncItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      enqueuedAt: parsedAt ?? DateTime.now(),
      payload: payload,
    );
  }
}

