class ReminderEscalationTracker {
  final Map<String, int> _snoozeCounts = <String, int>{};
  final Set<String> _snoozeEscalated = <String>{};
  final Set<String> _noResponseEscalated = <String>{};

  int snoozeCountFor(String reminderId) => _snoozeCounts[reminderId] ?? 0;

  int recordSnooze(String reminderId) {
    final next = (_snoozeCounts[reminderId] ?? 0) + 1;
    _snoozeCounts[reminderId] = next;
    return next;
  }

  /// Returns true only once per reminder until `resetReminder()` is called.
  bool shouldEscalateSnooze({
    required String reminderId,
    required int threshold,
  }) {
    final count = snoozeCountFor(reminderId);
    if (count < threshold) {
      return false;
    }
    if (_snoozeEscalated.contains(reminderId)) {
      return false;
    }
    _snoozeEscalated.add(reminderId);
    return true;
  }

  /// Returns true only once per reminder until `resetReminder()` is called.
  bool shouldEscalateNoResponse(String reminderId) {
    if (_noResponseEscalated.contains(reminderId)) {
      return false;
    }
    _noResponseEscalated.add(reminderId);
    return true;
  }

  void resetReminder(String reminderId) {
    _snoozeCounts.remove(reminderId);
    _snoozeEscalated.remove(reminderId);
    _noResponseEscalated.remove(reminderId);
  }

  void clear() {
    _snoozeCounts.clear();
    _snoozeEscalated.clear();
    _noResponseEscalated.clear();
  }
}

