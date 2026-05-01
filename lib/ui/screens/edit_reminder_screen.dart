import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/reminder_model.dart';
import '../../state/app_state.dart';

class EditReminderScreen extends StatefulWidget {
  const EditReminderScreen({super.key, required this.reminder});

  final ReminderModel reminder;

  @override
  State<EditReminderScreen> createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends State<EditReminderScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _medNameController;
  late final TextEditingController _doseController;

  final List<String> _times = <String>[];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _medNameController = TextEditingController(text: widget.reminder.medName);
    _doseController = TextEditingController(text: widget.reminder.dose);
    _doseController.addListener(_handleDoseChanged);

    final initialTimes = widget.reminder.times.isNotEmpty
        ? widget.reminder.times
        : <String>[widget.reminder.time];
    _times
      ..clear()
      ..addAll(initialTimes.map((e) => e.trim()).where((e) => e.isNotEmpty));
    if (_times.isEmpty) {
      _times.add('08:00');
    }
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
    _syncTimesWithDose(_desiredTimeSlotsFromDose(_doseController.text));
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
      while (_times.length < nextCount) {
        _times.add(_suggestedTimeForIndex(_times.length));
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
      _times[index] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
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
      await context.read<AppState>().updateReminder(
            localReminderId: widget.reminder.id,
            medName: _medNameController.text.trim(),
            dose: _doseController.text.trim(),
            time: normalizedTimes.first,
            times: normalizedTimes,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder updated.')),
      );
      Navigator.of(context).pop();
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
        const SnackBar(content: Text('Failed to update reminder.')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Reminder')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Basic Details',
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _save,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_submitting ? 'Saving...' : 'Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Advanced recipient settings remain unchanged in this prototype editor.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
