import 'package:hive/hive.dart';

import '../models/local_reminder.dart';

class LocalReminderStore {
  LocalReminderStore({required Box<Map> box}) : _box = box;

  final Box<Map> _box;

  List<LocalReminder> listSync({bool includeDeleted = false}) {
    final items = <LocalReminder>[];
    for (final entry in _box.toMap().entries) {
      final json = Map<String, dynamic>.from(entry.value);
      final reminder = LocalReminder.fromJson(json);
      if (!includeDeleted && !reminder.isActive) {
        continue;
      }
      items.add(reminder);
    }

    // Stable order: time then createdAt.
    items.sort((a, b) {
      final aTime = a.times.isNotEmpty ? a.times.first : a.time;
      final bTime = b.times.isNotEmpty ? b.times.first : b.time;
      final time = aTime.compareTo(bTime);
      if (time != 0) {
        return time;
      }
      return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
    });

    return items;
  }

  LocalReminder? getSync(String localId) {
    final value = _box.get(localId);
    if (value == null) {
      return null;
    }
    return LocalReminder.fromJson(Map<String, dynamic>.from(value));
  }

  Future<void> upsert(LocalReminder reminder) async {
    await _box.put(reminder.localId, reminder.toJson());
  }

  Future<void> deleteHard(String localId) async {
    await _box.delete(localId);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
