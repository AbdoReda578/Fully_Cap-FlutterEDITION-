import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;

import '../core/reminder_schedule.dart';
import '../models/local_reminder.dart';
import 'local_reminder_store.dart';
import 'notification_service.dart';

class ReminderNotificationScheduler {
  ReminderNotificationScheduler({
    required NotificationService notificationService,
    required LocalReminderStore reminderStore,
  }) : _notifications = notificationService,
       _store = reminderStore;

  final NotificationService _notifications;
  final LocalReminderStore _store;

  Future<void> rebuildSchedules({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    await _notifications.ensureInitialized();

    final details = _notifications.buildDetails(
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
    );

    await _notifications.cancelAll();

    final reminders = _store.listSync(includeDeleted: false);
    final location = tz.local;
    final now = tz.TZDateTime.now(location);

    for (final reminder in reminders) {
      final times = reminder.times.isNotEmpty
          ? reminder.times
          : <String>[reminder.time];
      final ids = reminder.repeatingNotificationIds.isNotEmpty
          ? reminder.repeatingNotificationIds
          : <int>[reminder.repeatingNotificationId];

      for (var index = 0; index < times.length; index += 1) {
        final time = times[index];
        final parsed = ReminderSchedule.parseTimeOfDay24h(time);
        if (parsed == null) {
          continue;
        }

        final firstFire = ReminderSchedule.nextDailyOccurrence(
          location: location,
          now: now,
          hour: parsed.hour,
          minute: parsed.minute,
        );

        final id = index < ids.length
            ? ids[index]
            : (reminder.repeatingNotificationId + index);
        if (id <= 0) {
          continue;
        }

        final payload = jsonEncode(<String, dynamic>{
          'type': 'reminder_due',
          'local_id': reminder.localId,
          'server_id': reminder.serverId,
          'time': time,
          'source': 'scheduled_daily',
        });

        await _notifications.scheduleDailyAtTime(
          id: id,
          title: 'Medication Reminder',
          body: '${reminder.medName} (${reminder.dose})',
          firstFire: firstFire,
          details: details,
          payload: payload,
        );
      }

      // Pending snooze one-shot.
      if (reminder.snoozedUntil != null &&
          reminder.snoozeNotificationId != null) {
        final snoozedUntil = reminder.snoozedUntil!;
        if (snoozedUntil.isAfter(DateTime.now())) {
          final snoozePayload = jsonEncode(<String, dynamic>{
            'type': 'reminder_due',
            'local_id': reminder.localId,
            'server_id': reminder.serverId,
            'time': reminder.time,
            'source': 'scheduled_snooze',
            'due_at': snoozedUntil.toIso8601String(),
          });

          await _notifications.scheduleOneShot(
            id: reminder.snoozeNotificationId!,
            title: 'Snoozed Reminder',
            body: '${reminder.medName} (${reminder.dose})',
            fireAt: tz.TZDateTime.from(snoozedUntil, location),
            details: details,
            payload: snoozePayload,
          );
        }
      }
    }
  }

  Future<void> cancelReminderNotifications(LocalReminder reminder) async {
    await _notifications.ensureInitialized();
    final repeatingIds = reminder.repeatingNotificationIds.isNotEmpty
        ? reminder.repeatingNotificationIds
        : <int>[reminder.repeatingNotificationId];
    for (final id in repeatingIds) {
      if (id <= 0) {
        continue;
      }
      await _notifications.cancel(id);
    }
    if (reminder.snoozeNotificationId != null) {
      await _notifications.cancel(reminder.snoozeNotificationId!);
    }
  }
}
