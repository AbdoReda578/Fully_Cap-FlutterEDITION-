import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:med_reminder_flutter/models/due_reminder_occurrence.dart';
import 'package:med_reminder_flutter/services/local_reminder_store.dart';
import 'package:med_reminder_flutter/services/notification_id_allocator.dart';
import 'package:med_reminder_flutter/services/sync_queue_store.dart';
import 'package:med_reminder_flutter/services/timezone_service.dart';
import 'package:med_reminder_flutter/state/app_state.dart';
import 'package:med_reminder_flutter/ui/screens/home_shell.dart';
import 'package:med_reminder_flutter/ui/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Developer Tools is reachable in debug builds', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = AppState(enableNotifications: false);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    final devTools = find.text('Developer Tools');
    await tester.scrollUntilVisible(
      devTools,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(devTools, findsOneWidget);
    await tester.tap(devTools);
    await tester.pumpAndSettle();

    // Password gate.
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      '_xotk',
    );
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Open')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notification Tools'), findsOneWidget);
  });

  testWidgets(
    'Due reminders are shown sequentially (queue not dropped)',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      late Box<Map> remindersBox;
      late Box<Map> queueBox;
      late Box<dynamic> metaBox;

      await tester.runAsync(() async {
        await setUpTestHive();
        remindersBox = await Hive.openBox<Map>('reminders_widget');
        queueBox = await Hive.openBox<Map>('queue_widget');
        metaBox = await Hive.openBox<dynamic>('meta_widget');
      });

      addTearDown(() async {
        await tester.runAsync(() async {
          await tearDownTestHive();
        });
      });

      final state = AppState(
        enableNotifications: false,
        localReminderStore: LocalReminderStore(box: remindersBox),
        syncQueueStore: SyncQueueStore(box: queueBox),
        notificationIdAllocator: NotificationIdAllocator(metaBox: metaBox),
        timezoneService: TimezoneService(metaBox: metaBox),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(home: HomeShell()),
        ),
      );

      final dueAt = DateTime(2026, 1, 1, 8, 0);
      await state.enqueueDueOccurrences(<DueReminderOccurrence>[
        DueReminderOccurrence(
          occurrenceId: 'r1|${dueAt.toIso8601String()}',
          reminderLocalId: 'r1',
          medName: 'Med A',
          dose: '1 pill',
          timeLabel: '08:00',
          forUser: 'You',
          dueAt: dueAt,
          source: 'test',
        ),
        DueReminderOccurrence(
          occurrenceId: 'r2|${dueAt.toIso8601String()}',
          reminderLocalId: 'r2',
          medName: 'Med B',
          dose: '2 pills',
          timeLabel: '08:00',
          forUser: 'You',
          dueAt: dueAt,
          source: 'test',
        ),
      ]);

      await tester.pumpAndSettle();
      expect(find.text('Med A'), findsOneWidget);

      await tester.tap(find.text('Taken'));
      await tester.pumpAndSettle();
      expect(find.text('Med B'), findsOneWidget);

      await tester.tap(find.text('Taken'));
      await tester.pumpAndSettle();

      expect(find.text('Medication Reminder!'), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets('Profile tab is reachable from HomeShell', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    late Box<Map> remindersBox;
    late Box<Map> queueBox;
    late Box<dynamic> metaBox;

    await tester.runAsync(() async {
      await setUpTestHive();
      remindersBox = await Hive.openBox<Map>('reminders_profile_widget');
      queueBox = await Hive.openBox<Map>('queue_profile_widget');
      metaBox = await Hive.openBox<dynamic>('meta_profile_widget');
    });

    addTearDown(() async {
      await tester.runAsync(() async {
        await tearDownTestHive();
      });
    });

    final state = AppState(
      enableNotifications: false,
      localReminderStore: LocalReminderStore(box: remindersBox),
      syncQueueStore: SyncQueueStore(box: queueBox),
      notificationIdAllocator: NotificationIdAllocator(metaBox: metaBox),
      timezoneService: TimezoneService(metaBox: metaBox),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: HomeShell()),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile is not ready yet.'), findsOneWidget);
  });
}
