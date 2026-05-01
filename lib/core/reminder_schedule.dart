import 'package:timezone/timezone.dart' as tz;

class ReminderSchedule {
  const ReminderSchedule._();

  static ({int hour, int minute})? parseTimeOfDay24h(String hhmm) {
    final parts = hhmm.trim().split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return (hour: hour, minute: minute);
  }

  static tz.TZDateTime nextDailyOccurrence({
    required tz.Location location,
    required tz.TZDateTime now,
    required int hour,
    required int minute,
  }) {
    final today = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!today.isBefore(now)) {
      return today;
    }
    return today.add(const Duration(days: 1));
  }
}

