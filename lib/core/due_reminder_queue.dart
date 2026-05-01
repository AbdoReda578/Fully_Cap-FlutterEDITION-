import 'dart:collection';

import '../models/due_reminder_occurrence.dart';

class DueReminderQueue {
  DueReminderQueue();

  final Queue<DueReminderOccurrence> _queue = Queue<DueReminderOccurrence>();
  final Set<String> _seenOccurrenceIds = <String>{};

  DueReminderOccurrence? _active;

  DueReminderOccurrence? get active => _active;

  List<DueReminderOccurrence> get pending =>
      List<DueReminderOccurrence>.unmodifiable(_queue);

  bool get hasWork => _active != null || _queue.isNotEmpty;

  void enqueue(DueReminderOccurrence occurrence) {
    if (_seenOccurrenceIds.contains(occurrence.occurrenceId)) {
      return;
    }
    _seenOccurrenceIds.add(occurrence.occurrenceId);
    _queue.addLast(occurrence);
  }

  void enqueueAll(Iterable<DueReminderOccurrence> occurrences) {
    for (final occurrence in occurrences) {
      enqueue(occurrence);
    }
  }

  /// Moves the next pending occurrence to active, if none is active.
  DueReminderOccurrence? takeNextIfIdle() {
    if (_active != null) {
      return _active;
    }
    if (_queue.isEmpty) {
      return null;
    }
    _active = _queue.removeFirst();
    return _active;
  }

  void completeActive() {
    _active = null;
  }

  void clear() {
    _queue.clear();
    _seenOccurrenceIds.clear();
    _active = null;
  }
}

