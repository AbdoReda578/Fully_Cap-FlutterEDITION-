import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/brand_palette.dart';
import '../../state/app_state.dart';
import 'tools_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _devToolsPassword = '_xotk';

  Future<bool> _promptDevToolsPassword(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Developer Tools'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) {
              Navigator.of(dialogContext).pop(true);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open'),
            ),
          ],
        );
      },
    );

    if (ok != true) {
      return false;
    }

    final password = controller.text.trim();
    if (password != _devToolsPassword) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Wrong password.')));
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final auraChipColor = BrandPalette.surfaceSoftByMode(context);

    return Consumer<AppState>(
      builder: (BuildContext context, AppState state, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Use a darker app theme'),
                      value: state.darkModeEnabled,
                      onChanged: state.setDarkModeEnabled,
                    ),
                    if (state.developerAuraEnabled)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Developer Aura Enabled'),
                          backgroundColor: auraChipColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Reminder Alerts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sound Alert'),
                      subtitle: const Text('Play sound when reminder appears'),
                      value: state.soundEnabled,
                      onChanged: state.setSoundEnabled,
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: state.soundId,
                      decoration: const InputDecoration(
                        labelText: 'Alert sound',
                        helperText: 'Choose what sound plays for reminders',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'beep',
                          child: Text('Beep (default)'),
                        ),
                        DropdownMenuItem(value: 'chime', child: Text('Chime')),
                        DropdownMenuItem(
                          value: 'system',
                          child: Text('System alert'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom sound'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          state.setSoundId(value);
                        }
                      },
                    ),
                    if (state.soundId == 'custom') ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        state.customSoundName == null
                            ? 'No custom sound selected.'
                            : 'Custom: ${state.customSoundName}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await state.pickCustomSound();
                              } on ApiException catch (e) {
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              } catch (_) {
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to pick sound.'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Choose Sound File'),
                          ),
                          if (state.customSoundName != null)
                            TextButton(
                              onPressed: state.clearCustomSound,
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: state.soundEnabled
                          ? state.playAlertSound
                          : null,
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('Test Sound'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tip: On Chrome/Web, you may need to tap "Test Sound" once to allow audio playback.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vibration Alert'),
                      subtitle: const Text(
                        'Vibrate device when reminder appears',
                      ),
                      value: state.vibrationEnabled,
                      onChanged: state.setVibrationEnabled,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: state.snoozeThreshold,
                      decoration: const InputDecoration(
                        labelText: 'Snooze escalation threshold',
                        helperText: 'Send family alert after this many snoozes',
                      ),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem(value: 3, child: Text('3 snoozes')),
                        DropdownMenuItem(value: 5, child: Text('5 snoozes')),
                      ],
                      onChanged: (int? value) {
                        if (value != null) {
                          state.setSnoozeThreshold(value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: state.criticalDelayMinutes,
                      decoration: const InputDecoration(
                        labelText: 'No-response critical delay',
                        helperText:
                            'Send critical family alert after this time',
                      ),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem(value: 15, child: Text('15 minutes')),
                        DropdownMenuItem(value: 30, child: Text('30 minutes')),
                        DropdownMenuItem(value: 45, child: Text('45 minutes')),
                        DropdownMenuItem(value: 60, child: Text('60 minutes')),
                      ],
                      onChanged: (int? value) {
                        if (value != null) {
                          state.setCriticalDelayMinutes(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Account',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(state.user?.email ?? 'N/A'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups_outlined),
                      title: const Text('Family ID'),
                      subtitle: Text(state.family?.familyId ?? 'Not connected'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: state.logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MedReminder keeps your medications on track with family safety escalation when reminders are ignored or repeatedly snoozed.',
                    ),
                  ],
                ),
              ),
            ),
            if (kDebugMode) ...<Widget>[
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Developer',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.build_outlined),
                        title: const Text('Developer Tools'),
                        subtitle: const Text('Debug-only utilities'),
                        onTap: () async {
                          final allowed = await _promptDevToolsPassword(
                            context,
                          );
                          if (!allowed || !context.mounted) {
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: const Text('Developer Tools'),
                                ),
                                body: const ToolsScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
