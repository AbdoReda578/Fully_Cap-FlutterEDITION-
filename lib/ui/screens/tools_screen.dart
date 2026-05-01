import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../state/app_state.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  static const Map<String, String> _templateOptions = <String, String>{
    'normal': 'Normal Reminder',
    'warning_snooze': 'Warning: Multiple Snoozes',
    'warning_rejected': 'Warning: Dose Rejected',
    'warning_dismissed': 'Warning: Reminder Dismissed',
    'critical_no_response': 'Critical: No Response',
    'critical_emergency': 'Critical: Emergency Alert',
    'followup_missed': 'Follow-up: Missed Dose',
    'success_taken': 'Success: Dose Taken',
  };

  String _templateType = 'normal';
  final Set<String> _selectedRecipients = <String>{};
  bool _busy = false;

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
    });

    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Developer Tools are not available in release builds.'),
        ),
      );
    }

    return Consumer<AppState>(
      builder: (BuildContext context, AppState state, _) {
        final emailStatus = state.emailStatus;
        final familyMembers = state.familyMembers;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Notification Tools',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Email System Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (emailStatus == null)
                      const Text('Status not loaded yet.')
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Configured: ${emailStatus.configured ? 'Yes' : 'No'}',
                          ),
                          Text('Provider: ${emailStatus.provider}'),
                          Text('Address: ${emailStatus.emailAddress}'),
                          Text(
                            'OAuth: ${emailStatus.oauthEnabled ? 'Enabled' : 'Disabled'}',
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                  await state.refreshEmailStatus();
                                }),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Status'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                  final message = await state
                                      .testGmailConnection();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }),
                          icon: const Icon(Icons.link),
                          label: const Text('Test Gmail OAuth'),
                        ),
                      ],
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
                      'Send Test Emails',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _templateType,
                      items: _templateOptions.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _templateType = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Template',
                        prefixIcon: Icon(Icons.mark_email_read_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (familyMembers.isEmpty)
                      const Text(
                        'No family members found. Add members in Family tab first.',
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: familyMembers
                            .map(
                              (String member) => FilterChip(
                                label: Text(member),
                                selected: _selectedRecipients.contains(member),
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedRecipients.add(member);
                                    } else {
                                      _selectedRecipients.remove(member);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                  if (_selectedRecipients.isEmpty) {
                                    throw ApiException(
                                      'Select at least one recipient.',
                                    );
                                  }
                                  final message = await state.sendTestEmail(
                                    recipients: _selectedRecipients.toList(),
                                    templateType: _templateType,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }),
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Send to Selected'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                  if (familyMembers.isEmpty) {
                                    throw ApiException(
                                      'No family members available.',
                                    );
                                  }
                                  final message = await state.sendTestEmail(
                                    recipients: familyMembers,
                                    templateType: _templateType,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }),
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text('Send to All'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
