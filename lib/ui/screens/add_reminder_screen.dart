import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../state/app_state.dart';
import 'barcode_scanner_screen.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _medNameController = TextEditingController(
    text: 'Paracetamol',
  );
  final TextEditingController _doseController = TextEditingController(
    text: '1 pill',
  );

  final List<String> _times = <String>['08:00'];
  String _notificationType = 'self';
  bool _emailNotifications = true;
  bool _calendarSync = false;

  String _singleMember = '';
  final Set<String> _selectedMembers = <String>{};

  bool _submitting = false;
  bool _loadingBarcode = false;

  @override
  void initState() {
    super.initState();
    _doseController.addListener(_handleDoseChanged);
    _syncTimesWithDose(_desiredTimeSlotsFromDose(_doseController.text));
  }

  @override
  void dispose() {
    _doseController.removeListener(_handleDoseChanged);
    _medNameController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  void _handleDoseChanged() {
    final target = _desiredTimeSlotsFromDose(_doseController.text);
    _syncTimesWithDose(target);
  }

  void _setDoseTextWithoutListener(String value) {
    _doseController.removeListener(_handleDoseChanged);
    _doseController.text = value;
    _doseController.addListener(_handleDoseChanged);
  }

  int _desiredTimeSlotsFromDose(String rawDose) {
    final match = RegExp(r'(\d+)').firstMatch(rawDose);
    final pills = int.tryParse(match?.group(1) ?? '');
    if (pills == null || pills < 2) {
      return 1;
    }
    return pills > 6 ? 6 : pills;
  }

  void _syncTimesWithDose(int targetCount) {
    final nextCount = targetCount < 1 ? 1 : targetCount;
    if (_times.length == nextCount) {
      return;
    }

    setState(() {
      if (_times.isEmpty) {
        _times.add('08:00');
      }
      while (_times.length < nextCount) {
        final index = _times.length;
        _times.add(_suggestedTimeForIndex(index));
      }
      while (_times.length > nextCount) {
        _times.removeLast();
      }
    });
  }

  String _suggestedTimeForIndex(int index) {
    final base = _times.isNotEmpty ? _times.first : '08:00';
    final parts = base.split(':');
    final baseHour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8;
    final baseMinute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final totalMinutes = (baseHour * 60) + baseMinute + (index * 240);
    final normalized = totalMinutes % (24 * 60);
    final hour = (normalized ~/ 60).toString().padLeft(2, '0');
    final minute = (normalized % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickTimeAt(int index) async {
    final current = index >= 0 && index < _times.length ? _times[index] : '08:00';
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      _times[index] = '$hour:$minute';
    });
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
    );

    if (!mounted || barcode == null || barcode.isEmpty) {
      return;
    }

    setState(() {
      _loadingBarcode = true;
    });

    try {
      final medication = await context.read<AppState>().lookupBarcode(barcode);
      if (!mounted) {
        return;
      }

      final targetSlots = _desiredTimeSlotsFromDose(medication.dose);
      final nextTimes = <String>[
        medication.time.trim().isEmpty ? '08:00' : medication.time.trim(),
      ];
      while (nextTimes.length < targetSlots) {
        final index = nextTimes.length;
        final parts = nextTimes.first.split(':');
        final baseHour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8;
        final baseMinute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
        final totalMinutes = (baseHour * 60) + baseMinute + (index * 240);
        final normalized = totalMinutes % (24 * 60);
        final hour = (normalized ~/ 60).toString().padLeft(2, '0');
        final minute = (normalized % 60).toString().padLeft(2, '0');
        nextTimes.add('$hour:$minute');
      }

      setState(() {
        _medNameController.text = medication.medName;
        _setDoseTextWithoutListener(medication.dose);
        _times
          ..clear()
          ..addAll(nextTimes);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded ${medication.medName} from barcode.')),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Barcode lookup failed.')));
    } finally {
      if (mounted) {
        setState(() {
          _loadingBarcode = false;
        });
      }
    }
  }

  Future<void> _submit(AppState state) async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    if (_notificationType != 'self' && state.familyMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add family members first or switch notification type to Only me.',
          ),
        ),
      );
      return;
    }

    if (_notificationType == 'family_single' && _singleMember.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select one family member.')),
      );
      return;
    }

    if (_notificationType == 'family_multiple' && _selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one family member.')),
      );
      return;
    }

    final normalizedTimes = _times
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (normalizedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one valid time.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await state.createReminder(
        medName: _medNameController.text.trim(),
        dose: _doseController.text.trim(),
        time: normalizedTimes.first,
        times: normalizedTimes,
        notificationType: _notificationType,
        selectedFamilyMembers: _selectedMembers.toList(),
        singleFamilyMember: _singleMember,
        emailNotifications: _emailNotifications,
        calendarSync: _calendarSync,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder created successfully.')),
      );

      setState(() {
        _medNameController.text = 'Paracetamol';
        _setDoseTextWithoutListener('1 pill');
        _times
          ..clear()
          ..add('08:00');
        _notificationType = 'self';
        _selectedMembers.clear();
        _singleMember = '';
        _emailNotifications = true;
        _calendarSync = false;
      });
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
        const SnackBar(content: Text('Failed to create reminder.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState state, _) {
        final familyMembers = state.familyMembers;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Barcode Scanner',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text('Scan medication to auto-fill details.'),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _loadingBarcode ? null : _scanBarcode,
                      icon: _loadingBarcode
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.qr_code_scanner),
                      label: Text(
                        _loadingBarcode ? 'Loading...' : 'Scan Barcode',
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Reminder Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _medNameController,
                        decoration: const InputDecoration(
                          labelText: 'Medication Name',
                          prefixIcon: Icon(Icons.medication_outlined),
                        ),
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Medication name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _doseController,
                        decoration: const InputDecoration(
                          labelText: 'Dose',
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                        ),
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Dose is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_times.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Dose indicates ${_times.length} pills. Set one time for each dose.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ...List<Widget>.generate(_times.length, (index) {
                        final label = _times.length == 1
                            ? 'Time'
                            : 'Time ${index + 1}';
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _times.length - 1 ? 0 : 10,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: label,
                                    prefixIcon: const Icon(
                                      Icons.schedule_outlined,
                                    ),
                                  ),
                                  child: Text(_times[index]),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () => _pickTimeAt(index),
                                child: const Text('Pick Time'),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _notificationType,
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'self',
                            child: Text('Only me'),
                          ),
                          DropdownMenuItem(
                            value: 'family_single',
                            child: Text('One family member'),
                          ),
                          DropdownMenuItem(
                            value: 'family_multiple',
                            child: Text('Multiple family members'),
                          ),
                          DropdownMenuItem(
                            value: 'family_all',
                            child: Text('All family members'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _notificationType = value;
                            _singleMember = '';
                            _selectedMembers.clear();
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Notification Recipients',
                          prefixIcon: Icon(Icons.groups_outlined),
                        ),
                      ),
                      if (_notificationType == 'family_single') ...<Widget>[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _singleMember.isEmpty
                              ? null
                              : _singleMember,
                          items: familyMembers
                              .map(
                                (String member) => DropdownMenuItem<String>(
                                  value: member,
                                  child: Text(member),
                                ),
                              )
                              .toList(),
                          onChanged: (String? value) {
                            setState(() {
                              _singleMember = value ?? '';
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Select family member',
                          ),
                        ),
                      ],
                      if (_notificationType == 'family_multiple') ...<Widget>[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: familyMembers
                              .map(
                                (String member) => FilterChip(
                                  label: Text(member),
                                  selected: _selectedMembers.contains(member),
                                  onSelected: (bool selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedMembers.add(member);
                                      } else {
                                        _selectedMembers.remove(member);
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (_notificationType == 'family_all') ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          familyMembers.isEmpty
                              ? 'No family members found.'
                              : '${familyMembers.length} family members will receive this reminder.',
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _emailNotifications,
                        onChanged: (bool value) {
                          setState(() {
                            _emailNotifications = value;
                          });
                        },
                        title: const Text('Email notifications'),
                        subtitle: const Text(
                          'Send interactive reminder emails',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _calendarSync,
                        onChanged: (bool value) {
                          setState(() {
                            _calendarSync = value;
                          });
                        },
                        title: const Text('Google Calendar sync'),
                        subtitle: const Text(
                          'Create a calendar event for this reminder',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : () => _submit(state),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_alert_outlined),
                          label: Text(
                            _submitting ? 'Creating...' : 'Create Reminder',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
