import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/local_reminder.dart';
import '../models/queued_sync_item.dart';
import 'api_service.dart';
import 'local_reminder_store.dart';
import 'sync_queue_store.dart';

class ReminderSyncService {
  ReminderSyncService({
    required ApiService api,
    required LocalReminderStore reminderStore,
    required SyncQueueStore queueStore,
  }) : _api = api,
       _reminderStore = reminderStore,
       _queueStore = queueStore;

  final ApiService _api;
  final LocalReminderStore _reminderStore;
  final SyncQueueStore _queueStore;

  Future<void> refreshFromServer(String token) async {
    final remote = await _api.getReminders(token);

    final localsAll = _reminderStore.listSync(includeDeleted: true);
    final localsByServerId = <String, LocalReminder>{};
    final localsPendingCreate = <LocalReminder>[];

    for (final local in localsAll) {
      if (local.serverId != null && local.serverId!.isNotEmpty) {
        localsByServerId[local.serverId!] = local;
      }
      if (local.pendingCreate && !local.isDeleted && !local.pendingDelete) {
        localsPendingCreate.add(local);
      }
    }

    // Upsert remote reminders (do not wipe local-only pending creates).
    for (final item in remote) {
      final serverId = item.id;
      final existing = localsByServerId[serverId];
      final merged = LocalReminder(
        localId: existing?.localId ?? serverId,
        serverId: serverId,
        userEmail: item.userEmail,
        medName: item.medName,
        dose: item.dose,
        time: item.time,
        times: item.times,
        notificationType: item.notificationType,
        selectedFamilyMembers: item.selectedFamilyMembers,
        singleFamilyMember: existing?.singleFamilyMember ?? '',
        emailNotifications: item.emailNotifications,
        calendarSync: existing?.calendarSync ?? false,
        createdAt: item.createdAt,
        repeatingNotificationId: existing?.repeatingNotificationId ?? 0,
        repeatingNotificationIds: existing?.repeatingNotificationIds,
        snoozeNotificationId: existing?.snoozeNotificationId,
        snoozedUntil: existing?.snoozedUntil,
        pendingCreate: false,
        pendingDelete: existing?.pendingDelete ?? false,
        isDeleted: existing?.isDeleted ?? false,
      );
      await _reminderStore.upsert(merged);
    }

    // Keep pending creates untouched.
    for (final local in localsPendingCreate) {
      await _reminderStore.upsert(local);
    }
  }

  Future<void> processQueue(String token) async {
    final items = _queueStore.listSync();
    if (items.isEmpty) {
      return;
    }

    // First pass: reminder creates/deletes (so actions can reference server ids).
    for (final (key, item) in items) {
      if (item.type != 'reminder_create' && item.type != 'reminder_delete') {
        continue;
      }
      await _processOne(token, key, item);
    }

    // Second pass: reminder updates (after create/delete).
    for (final (key, item) in items) {
      if (item.type != 'reminder_update') {
        continue;
      }
      await _processOne(token, key, item);
    }

    // Third pass: actions/escalations.
    for (final (key, item) in items) {
      if (item.type == 'reminder_create' ||
          item.type == 'reminder_delete' ||
          item.type == 'reminder_update') {
        continue;
      }
      await _processOne(token, key, item);
    }
  }

  Future<void> _processOne(
    String token,
    dynamic key,
    QueuedSyncItem item,
  ) async {
    try {
      if (item.type == 'reminder_create') {
        await _syncCreate(token, item);
        await _queueStore.remove(key);
        return;
      }

      if (item.type == 'reminder_delete') {
        await _syncDelete(token, item);
        await _queueStore.remove(key);
        return;
      }

      if (item.type == 'reminder_action') {
        await _syncAction(token, item);
        await _queueStore.remove(key);
        return;
      }

      if (item.type == 'reminder_update') {
        await _syncUpdate(token, item);
        await _queueStore.remove(key);
        return;
      }

      if (item.type == 'reminder_escalate') {
        await _syncEscalate(token, item);
        await _queueStore.remove(key);
        return;
      }

      // Unknown item type: drop so queue doesn't get stuck forever.
      debugPrint('Dropping unknown sync item: ${item.type}');
      await _queueStore.remove(key);
    } on ApiException catch (error) {
      // Deferrable: action references a reminder that hasn't been created on the
      // server yet. Keep it queued for the next sync attempt.
      if (error.statusCode == 409) {
        return;
      }
      rethrow;
    } catch (error) {
      debugPrint('Sync item failed (${item.type}): $error');
      rethrow;
    }
  }

  Future<void> _syncCreate(String token, QueuedSyncItem item) async {
    final localId = (item.payload['local_id'] ?? '').toString();
    final local = _reminderStore.getSync(localId);
    if (local == null) {
      return;
    }

    // Already synced?
    if (local.serverId != null && local.serverId!.isNotEmpty) {
      await _reminderStore.upsert(local.copyWith(pendingCreate: false));
      return;
    }

    final created = await _api.createReminder(
      token,
      medName: local.medName,
      dose: local.dose,
      time: local.time,
      times: local.times,
      notificationType: local.notificationType,
      selectedFamilyMembers: local.selectedFamilyMembers,
      singleFamilyMember: local.singleFamilyMember,
      emailNotifications: local.emailNotifications,
      calendarSync: local.calendarSync,
    );

    await _reminderStore.upsert(
      local.copyWith(serverId: created.id, pendingCreate: false),
    );
  }

  Future<void> _syncDelete(String token, QueuedSyncItem item) async {
    final localId = (item.payload['local_id'] ?? '').toString();
    final local = _reminderStore.getSync(localId);
    if (local == null) {
      return;
    }

    // Local-only reminder: delete locally, nothing to sync.
    if (local.serverId == null || local.serverId!.isEmpty) {
      await _reminderStore.deleteHard(localId);
      return;
    }

    await _api.deleteReminder(token, local.serverId!);
    await _reminderStore.deleteHard(localId);
  }

  Future<void> _syncUpdate(String token, QueuedSyncItem item) async {
    final localId = (item.payload['local_id'] ?? '').toString();
    final local = _reminderStore.getSync(localId);
    if (local == null) {
      return;
    }

    final serverId = local.serverId;
    if (serverId == null || serverId.isEmpty) {
      // Cannot send yet; reminder likely pending create.
      throw ApiException('Reminder not synced yet', statusCode: 409);
    }

    await _api.updateReminder(
      token,
      reminderId: serverId,
      medName: local.medName,
      dose: local.dose,
      time: local.time,
      times: local.times,
      notificationType: local.notificationType,
      selectedFamilyMembers: local.selectedFamilyMembers,
      singleFamilyMember: local.singleFamilyMember,
      emailNotifications: local.emailNotifications,
      calendarSync: local.calendarSync,
    );
  }

  Future<void> _syncAction(String token, QueuedSyncItem item) async {
    final localId = (item.payload['local_id'] ?? '').toString();
    final serverIdPayload = (item.payload['server_id'] ?? '').toString().trim();
    final action = (item.payload['action'] ?? '').toString();
    if (action.isEmpty) {
      return;
    }

    String serverId = serverIdPayload;
    if (serverId.isEmpty && localId.isNotEmpty) {
      final local = _reminderStore.getSync(localId);
      serverId = local?.serverId ?? '';
    }
    if (serverId.isEmpty) {
      // Cannot send yet; reminder likely pending create.
      throw ApiException('Reminder not synced yet', statusCode: 409);
    }

    await _api.recordReminderAction(
      token,
      reminderId: serverId,
      action: action,
      occurredAt: (item.payload['occurred_at'] ?? '').toString(),
      metadata: (item.payload['metadata'] is Map<String, dynamic>)
          ? item.payload['metadata'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
  }

  Future<void> _syncEscalate(String token, QueuedSyncItem item) async {
    final localId = (item.payload['local_id'] ?? '').toString();
    final serverIdPayload = (item.payload['server_id'] ?? '').toString().trim();
    final reason = (item.payload['reason'] ?? '').toString();
    if (reason.isEmpty) {
      return;
    }

    String serverId = serverIdPayload;
    if (serverId.isEmpty && localId.isNotEmpty) {
      final local = _reminderStore.getSync(localId);
      serverId = local?.serverId ?? '';
    }
    if (serverId.isEmpty) {
      // Cannot send yet; reminder likely pending create.
      throw ApiException('Reminder not synced yet', statusCode: 409);
    }

    final snoozeCount =
        int.tryParse((item.payload['snooze_count'] ?? 0).toString()) ?? 0;
    final delayMinutes =
        int.tryParse((item.payload['delay_minutes'] ?? 30).toString()) ?? 30;

    await _api.escalateReminder(
      token,
      reminderId: serverId,
      reason: reason,
      snoozeCount: snoozeCount,
      delayMinutes: delayMinutes,
    );
  }
}
