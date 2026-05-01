import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class TimezoneService {
  TimezoneService({required Box<dynamic> metaBox}) : _metaBox = metaBox;

  final Box<dynamic> _metaBox;

  static const String _lastTzKey = 'last_timezone_name_v1';

  /// Initializes tz database and sets [tz.local] to the device timezone.
  ///
  /// Returns true if the timezone changed since the last call (persisted).
  Future<bool> ensureInitializedAndCheckChanged() async {
    tz_data.initializeTimeZones();

    String tzName;
    try {
      tzName = await FlutterTimezone.getLocalTimezone();
    } catch (error) {
      debugPrint('TimezoneService.getLocalTimezone failed: $error');
      tzName = 'UTC';
    }

    try {
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (error) {
      debugPrint('TimezoneService.setLocalLocation failed ($tzName): $error');
      tz.setLocalLocation(tz.getLocation('UTC'));
      tzName = 'UTC';
    }

    final previous = (_metaBox.get(_lastTzKey) as String?)?.trim();
    await _metaBox.put(_lastTzKey, tzName);
    return previous != null && previous.isNotEmpty && previous != tzName;
  }
}

