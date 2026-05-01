import 'package:hive/hive.dart';

class NotificationIdAllocator {
  NotificationIdAllocator({required Box<dynamic> metaBox}) : _metaBox = metaBox;

  final Box<dynamic> _metaBox;

  static const String _nextIdKey = 'next_notification_id_v1';

  Future<int> allocate() async {
    final current = (_metaBox.get(_nextIdKey) as int?) ?? 1000;
    final next = current + 1;
    await _metaBox.put(_nextIdKey, next);
    return current;
  }
}

