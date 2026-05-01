import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:med_reminder_flutter/core/reminder_schedule.dart';
import 'package:med_reminder_flutter/models/local_reminder.dart';
import 'package:med_reminder_flutter/services/local_reminder_store.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('ReminderSchedule.nextDailyOccurrence computes next fire time', () {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));

    final location = tz.local;
    final now = tz.TZDateTime(location, 2026, 1, 1, 7, 0);

    final next = ReminderSchedule.nextDailyOccurrence(
      location: location,
      now: now,
      hour: 8,
      minute: 30,
    );
    expect(next, tz.TZDateTime(location, 2026, 1, 1, 8, 30));

    final after = tz.TZDateTime(location, 2026, 1, 1, 9, 0);
    final next2 = ReminderSchedule.nextDailyOccurrence(
      location: location,
      now: after,
      hour: 8,
      minute: 30,
    );
    expect(next2, tz.TZDateTime(location, 2026, 1, 2, 8, 30));
  });

  test('LocalReminderStore can read/write reminders', () async {
    await setUpTestHive();
    addTearDown(() async {
      await tearDownTestHive();
    });

    final box = await Hive.openBox<Map>('reminders_test');
    final store = LocalReminderStore(box: box);

    final reminder = LocalReminder(
      localId: 'local-1',
      serverId: 'server-1',
      userEmail: 'user@gmail.com',
      medName: 'Paracetamol',
      dose: '1 pill',
      time: '08:00',
      notificationType: 'self',
      selectedFamilyMembers: const <String>[],
      singleFamilyMember: '',
      emailNotifications: false,
      calendarSync: false,
      createdAt: '2026-01-01T00:00:00.000Z',
      repeatingNotificationId: 1234,
    );

    await store.upsert(reminder);

    final loaded = store.getSync('local-1');
    expect(loaded, isNotNull);
    expect(loaded!.serverId, 'server-1');
    expect(loaded.repeatingNotificationId, 1234);

    final list = store.listSync();
    expect(list.length, 1);
    expect(list.first.localId, 'local-1');
  });
}

