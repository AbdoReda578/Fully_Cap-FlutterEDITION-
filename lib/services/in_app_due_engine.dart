import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/reminder_schedule.dart';
import '../models/due_reminder_occurrence.dart';
import '../models/local_reminder.dart';
import 'local_reminder_store.dart';

/// Schedules in-app due events without polling the backend.
///
/// This is only for in-app UI (modals/lists) while the app is running.
/// OS notifications are scheduled separately via [ReminderNotificationScheduler].
class InAppDueEngine {
  InAppDueEngine({
    required LocalReminderStore store,
    required String Function() currentUserEmail,
  }) : _store = store,
       _currentUserEmail = currentUserEmail;

  final LocalReminderStore _store;
  final String Function() _currentUserEmail;

  final StreamController<List<DueReminderOccurrence>> _dueController =
      StreamController<List<DueReminderOccurrence>>.broadcast();

  Stream<List<DueReminderOccurrence>> get dueEvents => _dueController.stream;

  Timer? _timer;

  bool get isRunning => _timer != null;

  void start() {
    _scheduleNext();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void rebuild() {
    stop();
    start();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = null;

    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    final reminders = _store.listSync(includeDeleted: false);

    tz.TZDateTime? nextAt;
    for (final reminder in reminders) {
      final dueAt = _nextDueAtForReminder(reminder, now, location);
      if (dueAt == null) {
        continue;
      }
      if (nextAt == null || dueAt.isBefore(nextAt)) {
        nextAt = dueAt;
      }
    }

    if (nextAt == null) {
      return;
    }

    final target = nextAt;
    final duration = target.difference(now);
    final wait = duration.isNegative ? Duration.zero : duration;

    _timer = Timer(wait, () {
      _onTimerFire(target);
    });
  }

  tz.TZDateTime? _nextDueAtForReminder(
    LocalReminder reminder,
    tz.TZDateTime now,
    tz.Location location,
  ) {
    // Pending snooze.
    final snoozedUntil = reminder.snoozedUntil;
    if (snoozedUntil != null) {
      final snoozeAt = tz.TZDateTime.from(snoozedUntil, location);
      if (!snoozeAt.isBefore(now)) {
        return snoozeAt;
      }
    }

    final times = reminder.times.isNotEmpty
        ? reminder.times
        : <String>[reminder.time];
    if (times.isEmpty) {
      return null;
    }

    // Use a tiny grace window: if now is within 2s after the scheduled minute,
    // treat it as still due "today" so we don't miss it due to timer slop.
    final graceNow = now.subtract(const Duration(seconds: 2));

    tz.TZDateTime? earliest;
    for (final time in times) {
      final parsed = ReminderSchedule.parseTimeOfDay24h(time);
      if (parsed == null) {
        continue;
      }
      final next = ReminderSchedule.nextDailyOccurrence(
        location: location,
        now: graceNow,
        hour: parsed.hour,
        minute: parsed.minute,
      );
      if (earliest == null || next.isBefore(earliest)) {
        earliest = next;
      }
    }

    return earliest;
  }

  Future<void> _onTimerFire(tz.TZDateTime target) async {
    try {
      final location = tz.local;
      final now = tz.TZDateTime.now(location);
      final reminders = _store.listSync(includeDeleted: false);

      final due = <DueReminderOccurrence>[];
      final currentEmail = _currentUserEmail();

      for (final reminder in reminders) {
        final dueAt = _nextDueAtForReminder(reminder, now, location);
        if (dueAt == null) {
          continue;
        }

        // Group by "same scheduled moment" (within a second).
        if ((dueAt.difference(target)).inSeconds.abs() <= 1) {
          final hour = target.hour.toString().padLeft(2, '0');
          final minute = target.minute.toString().padLeft(2, '0');
          final timeLabel = '$hour:$minute';
          due.add(
            DueReminderOccurrence(
              occurrenceId: '${reminder.localId}|${target.toIso8601String()}',
              reminderLocalId: reminder.localId,
              reminderServerId: reminder.serverId,
              medName: reminder.medName,
              dose: reminder.dose,
              timeLabel: timeLabel,
              forUser: currentEmail,
              dueAt: target.toLocal(),
              source: reminder.snoozedUntil != null ? 'timer_snooze' : 'timer',
            ),
          );

          // Snoozes are one-shot: once due, clear state so we don't keep
          // rescheduling the same snooze time in-app.
          if (reminder.snoozedUntil != null) {
            await _store.upsert(
              reminder.copyWith(snoozedUntil: null, snoozeNotificationId: null),
            );
          }
        }
      }

      if (due.isNotEmpty && !_dueController.isClosed) {
        _dueController.add(due);
      }
    } catch (error) {
      debugPrint('InAppDueEngine timer handler failed: $error');
    } finally {
      _scheduleNext();
    }
  }

  Future<void> dispose() async {
    stop();
    await _dueController.close();
  }
}
