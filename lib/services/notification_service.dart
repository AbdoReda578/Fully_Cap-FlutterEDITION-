import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationTapEvent {
  NotificationTapEvent({
    required this.payload,
    required this.actionId,
  });

  final String? payload;
  final String? actionId;

  Map<String, dynamic>? tryParsePayloadJson() {
    final raw = payload;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }
}

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  final StreamController<NotificationTapEvent> _tapController =
      StreamController<NotificationTapEvent>.broadcast();

  bool _initialized = false;

  Stream<NotificationTapEvent> get taps => _tapController.stream;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _tapController.add(
          NotificationTapEvent(
            payload: response.payload,
            actionId: response.actionId,
          ),
        );
      },
    );

    // Runtime permissions.
    if (!kIsWeb) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();

      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null) {
      return null;
    }
    if (details.didNotificationLaunchApp != true) {
      return null;
    }
    return details.notificationResponse?.payload;
  }

  static const String channelId = 'med_reminder_reminders';
  static const String channelName = 'Medication Reminders';
  static const String channelDescription = 'Local reminder notifications';

  NotificationDetails buildDetails({
    required bool playSound,
    required bool enableVibration,
  }) {
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: enableVibration,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: playSound,
      presentBadge: true,
    );

    return NotificationDetails(android: android, iOS: ios);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> scheduleDailyAtTime({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime firstFire,
    required NotificationDetails details,
    required String payload,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      firstFire,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> scheduleOneShot({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime fireAt,
    required NotificationDetails details,
    required String payload,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      fireAt,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }
}

