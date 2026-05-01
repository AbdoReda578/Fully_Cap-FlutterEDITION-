import 'package:hive/hive.dart';

import '../models/queued_sync_item.dart';

class SyncQueueStore {
  SyncQueueStore({required Box<Map> box}) : _box = box;

  final Box<Map> _box;

  bool get hasItems => _box.isNotEmpty;

  /// Returns queued items in insertion order.
  List<(dynamic key, QueuedSyncItem item)> listSync() {
    final out = <(dynamic, QueuedSyncItem)>[];

    // `add()` uses integer keys; sorting makes ordering explicit.
    final keys = _box.keys.toList();
    keys.sort((a, b) {
      if (a is int && b is int) {
        return a.compareTo(b);
      }
      return a.toString().compareTo(b.toString());
    });

    for (final key in keys) {
      final raw = _box.get(key);
      if (raw is! Map) {
        continue;
      }
      final item = QueuedSyncItem.fromJson(Map<String, dynamic>.from(raw));
      out.add((key, item));
    }

    return out;
  }

  Future<void> enqueue(QueuedSyncItem item) async {
    await _box.add(item.toJson());
  }

  Future<void> remove(dynamic key) async {
    await _box.delete(key);
  }

  Future<void> clear() async {
    await _box.clear();
  }
}

