import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_flutter/core/reminder_escalation_tracker.dart';

void main() {
  test('Snooze threshold escalation triggers once per reminder until reset', () {
    final tracker = ReminderEscalationTracker();
    const id = 'rem-1';

    expect(tracker.snoozeCountFor(id), 0);
    tracker.recordSnooze(id);
    tracker.recordSnooze(id);
    expect(tracker.shouldEscalateSnooze(reminderId: id, threshold: 3), isFalse);

    tracker.recordSnooze(id);
    expect(tracker.snoozeCountFor(id), 3);
    expect(tracker.shouldEscalateSnooze(reminderId: id, threshold: 3), isTrue);
    expect(tracker.shouldEscalateSnooze(reminderId: id, threshold: 3), isFalse);

    tracker.resetReminder(id);
    tracker.recordSnooze(id);
    tracker.recordSnooze(id);
    tracker.recordSnooze(id);
    expect(tracker.shouldEscalateSnooze(reminderId: id, threshold: 3), isTrue);
  });

  test('No-response escalation triggers once per reminder until reset', () {
    final tracker = ReminderEscalationTracker();
    const id = 'rem-2';

    expect(tracker.shouldEscalateNoResponse(id), isTrue);
    expect(tracker.shouldEscalateNoResponse(id), isFalse);

    tracker.resetReminder(id);
    expect(tracker.shouldEscalateNoResponse(id), isTrue);
  });
}

