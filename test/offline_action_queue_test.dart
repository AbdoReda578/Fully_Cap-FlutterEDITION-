import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:med_reminder_flutter/core/api_exception.dart';
import 'package:med_reminder_flutter/models/local_reminder.dart';
import 'package:med_reminder_flutter/models/queued_sync_item.dart';
import 'package:med_reminder_flutter/services/api_service.dart';
import 'package:med_reminder_flutter/services/local_reminder_store.dart';
import 'package:med_reminder_flutter/services/reminder_sync_service.dart';
import 'package:med_reminder_flutter/services/sync_queue_store.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  test('Offline action stays queued and is sent later when online', () async {
    await setUpTestHive();
    addTearDown(() async {
      await tearDownTestHive();
    });

    final remindersBox = await Hive.openBox<Map>('reminders_box');
    final queueBox = await Hive.openBox<Map>('queue_box');

    final store = LocalReminderStore(box: remindersBox);
    final queue = SyncQueueStore(box: queueBox);

    await store.upsert(
      LocalReminder(
        localId: 'local-1',
        serverId: 'server-1',
        userEmail: 'user@gmail.com',
        medName: 'Med',
        dose: '1',
        time: '08:00',
        notificationType: 'self',
        selectedFamilyMembers: const <String>[],
        singleFamilyMember: '',
        emailNotifications: false,
        calendarSync: false,
        createdAt: '2026-01-01T00:00:00.000Z',
        repeatingNotificationId: 10,
      ),
    );

    await queue.enqueue(
      QueuedSyncItem(
        id: 'q1',
        type: 'reminder_action',
        enqueuedAt: DateTime(2026, 1, 1),
        payload: <String, dynamic>{
          'local_id': 'local-1',
          'action': 'taken',
          'occurred_at': '2026-01-01T08:00:00.000Z',
          'metadata': <String, dynamic>{},
        },
      ),
    );

    final api = MockApiService();
    final sync = ReminderSyncService(api: api, reminderStore: store, queueStore: queue);

    when(
      () => api.recordReminderAction(
        any(),
        reminderId: any(named: 'reminderId'),
        action: any(named: 'action'),
        occurredAt: any(named: 'occurredAt'),
        metadata: any(named: 'metadata'),
      ),
    ).thenThrow(ApiException('offline'));

    expect(() => sync.processQueue('token'), throwsA(isA<ApiException>()));
    expect(queue.hasItems, isTrue);

    reset(api);
    when(
      () => api.recordReminderAction(
        any(),
        reminderId: any(named: 'reminderId'),
        action: any(named: 'action'),
        occurredAt: any(named: 'occurredAt'),
        metadata: any(named: 'metadata'),
      ),
    ).thenAnswer((_) async {});

    await sync.processQueue('token');
    expect(queue.hasItems, isFalse);
    verify(
      () => api.recordReminderAction(
        'token',
        reminderId: 'server-1',
        action: 'taken',
        occurredAt: any(named: 'occurredAt'),
        metadata: any(named: 'metadata'),
      ),
    ).called(1);
  });
}

