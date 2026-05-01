class DueReminderOccurrence {
  DueReminderOccurrence({
    required this.occurrenceId,
    required this.reminderLocalId,
    this.reminderServerId,
    required this.medName,
    required this.dose,
    required this.timeLabel,
    required this.forUser,
    required this.dueAt,
    required this.source,
  });

  final String occurrenceId;
  final String reminderLocalId;
  final String? reminderServerId;
  final String medName;
  final String dose;
  final String timeLabel;
  final String forUser;
  final DateTime dueAt;

  /// e.g. `timer`, `notification_tap`
  final String source;
}
