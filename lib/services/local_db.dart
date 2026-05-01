import 'package:hive_flutter/hive_flutter.dart';

class LocalDb {
  const LocalDb._();

  static const String remindersBoxName = 'local_reminders_v1';
  static const String syncQueueBoxName = 'local_sync_queue_v1';
  static const String metaBoxName = 'local_meta_v1';

  static bool _initialized = false;

  static late Box<Map> remindersBox;
  static late Box<Map> syncQueueBox;
  static late Box<dynamic> metaBox;

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await Hive.initFlutter();

    remindersBox = await Hive.openBox<Map>(remindersBoxName);
    syncQueueBox = await Hive.openBox<Map>(syncQueueBoxName);
    metaBox = await Hive.openBox<dynamic>(metaBoxName);

    _initialized = true;
  }
}
