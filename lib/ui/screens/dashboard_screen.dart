import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/brand_palette.dart';
import '../../models/reminder_model.dart';
import '../../state/app_state.dart';
import '../widgets/summary_card.dart';
import 'edit_reminder_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onAddReminderTap});

  final VoidCallback onAddReminderTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debugChipColor = BrandPalette.surfaceSoftByMode(context);

    return Consumer<AppState>(
      builder: (BuildContext context, AppState state, _) {
        final userEmail = state.user?.email ?? '';
        final yourReminders = state.reminders
            .where((item) => item.userEmail == userEmail)
            .length;
        final profile = state.profile;
        final displayName = (profile?.displayName ?? '').trim();
        final title = (profile?.title ?? '').trim();
        final greetingName = displayName.isEmpty
            ? userEmail
            : '$displayName ($userEmail)';

        return RefreshIndicator(
          onRefresh: state.refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (state.developerAuraEnabled)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Developer Aura'),
                    backgroundColor: debugChipColor,
                  ),
                ),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(greetingName, style: Theme.of(context).textTheme.bodyMedium),
              if (title.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'Title: $title',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BrandPalette.primaryViolet,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 720 ? 3 : 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: MediaQuery.of(context).size.width > 720
                    ? 2.8
                    : 3.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  SummaryCard(
                    icon: Icons.notifications_active_outlined,
                    label: 'Active Reminders',
                    value: state.reminders.length.toString(),
                    color: BrandPalette.primaryBlue,
                  ),
                  SummaryCard(
                    icon: Icons.people_outline,
                    label: 'Family Members',
                    value: (state.familyMembers.length + 1).toString(),
                    color: BrandPalette.primaryDeep,
                  ),
                  SummaryCard(
                    icon: Icons.person_outline,
                    label: 'Your Reminders',
                    value: yourReminders.toString(),
                    color: BrandPalette.primaryViolet,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Text(
                    'Medication Reminders',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onAddReminderTap,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (state.reminders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: theme.cardColor,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        blurRadius: 12,
                        color: BrandPalette.shadowSoft,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      const Icon(
                        Icons.medication_liquid_outlined,
                        size: 56,
                        color: BrandPalette.primaryViolet,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No reminders yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text('Add your first medication reminder.'),
                    ],
                  ),
                )
              else
                ...state.reminders.map(
                  (reminder) => _ReminderCard(
                    reminder: reminder,
                    medName: reminder.medName,
                    dose: reminder.dose,
                    time: _formatReminderTimes(reminder),
                    notificationType: reminder.notificationType,
                    recipientsCount: reminder.selectedFamilyMembers.length,
                    emailNotifications: reminder.emailNotifications,
                    developerAuraEnabled: state.developerAuraEnabled,
                    debugChipColor: debugChipColor,
                    onEdit: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              EditReminderScreen(reminder: reminder),
                        ),
                      );
                    },
                    onDelete: () async {
                      try {
                        await state.deleteReminder(reminder.id);
                      } on ApiException catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error.message)));
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _formatReminderTimes(ReminderModel reminder) {
  final times = reminder.times.isNotEmpty
      ? reminder.times
      : <String>[reminder.time];
  if (times.isEmpty) {
    return reminder.time;
  }
  if (times.length <= 2) {
    return times.join(', ');
  }
  return '${times[0]}, ${times[1]} (+${times.length - 2} more)';
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.medName,
    required this.dose,
    required this.time,
    required this.notificationType,
    required this.recipientsCount,
    required this.emailNotifications,
    required this.developerAuraEnabled,
    required this.debugChipColor,
    required this.onEdit,
    required this.onDelete,
  });

  final ReminderModel reminder;
  final String medName;
  final String dose;
  final String time;
  final String notificationType;
  final int recipientsCount;
  final bool emailNotifications;
  final bool developerAuraEnabled;
  final Color debugChipColor;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;

  String get _notificationLabel {
    switch (notificationType) {
      case 'family_single':
        return '1 family member';
      case 'family_multiple':
        return '$recipientsCount family members';
      case 'family_all':
        return 'All family members';
      default:
        return 'Only me';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.medication_outlined,
                  color: BrandPalette.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    medName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit reminder',
                ),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Delete reminder?'),
                          content: const Text('This action cannot be undone.'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirm == true) {
                      await onDelete();
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('Dose: $dose')),
                Chip(label: Text('Time: $time')),
                Chip(label: Text(_notificationLabel)),
                if (emailNotifications)
                  const Chip(label: Text('Email: Enabled')),
                if (developerAuraEnabled)
                  Chip(
                    label: Text('DBG:${reminder.id.substring(0, 6)}'),
                    backgroundColor: debugChipColor,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
