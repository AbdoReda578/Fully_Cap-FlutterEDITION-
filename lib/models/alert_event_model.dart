class AlertEventModel {
  AlertEventModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.reminderId,
    required this.createdBy,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String createdAt;
  final String? reminderId;
  final String? createdBy;

  factory AlertEventModel.fromJson(Map<String, dynamic> json) {
    return AlertEventModel(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      reminderId: json['reminder_id']?.toString(),
      createdBy: json['created_by']?.toString(),
    );
  }
}
