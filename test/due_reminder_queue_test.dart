import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_flutter/core/due_reminder_queue.dart';
import 'package:med_reminder_flutter/models/due_reminder_occurrence.dart';

void main() {
  test('DueReminderQueue preserves multiple reminders in the same minute', () {
    final queue = DueReminderQueue();

    final now = DateTime(2026, 1, 1, 8, 0);
    final a = DueReminderOccurrence(
      occurrenceId: 'a|${now.toIso8601String()}',
      reminderLocalId: 'a',
      medName: 'Med A',
      dose: '1 pill',
      timeLabel: '08:00',
      forUser: 'You',
      dueAt: now,
      source: 'test',
    );
    final b = DueReminderOccurrence(
      occurrenceId: 'b|${now.toIso8601String()}',
      reminderLocalId: 'b',
      medName: 'Med B',
      dose: '2 pills',
      timeLabel: '08:00',
      forUser: 'You',
      dueAt: now,
      source: 'test',
    );

    queue.enqueueAll(<DueReminderOccurrence>[a, b]);

    expect(queue.active, isNull);
    expect(queue.pending.length, 2);

    expect(queue.takeNextIfIdle()?.reminderLocalId, 'a');
    expect(queue.active?.reminderLocalId, 'a');
    expect(queue.pending.length, 1);

    queue.completeActive();
    expect(queue.active, isNull);

    expect(queue.takeNextIfIdle()?.reminderLocalId, 'b');
    expect(queue.pending, isEmpty);
  });

  test('DueReminderQueue ignores duplicate occurrenceIds', () {
    final queue = DueReminderQueue();
    final now = DateTime(2026, 1, 1, 8, 0);
    final occ = DueReminderOccurrence(
      occurrenceId: 'dup|${now.toIso8601String()}',
      reminderLocalId: 'dup',
      medName: 'Dup',
      dose: '1',
      timeLabel: '08:00',
      forUser: 'You',
      dueAt: now,
      source: 'test',
    );

    queue.enqueue(occ);
    queue.enqueue(occ);
    expect(queue.pending.length, 1);
  });
}

