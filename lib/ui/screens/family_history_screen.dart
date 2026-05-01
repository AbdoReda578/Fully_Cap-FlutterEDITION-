import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/care_patient_model.dart';
import '../../state/app_state.dart';

class FamilyHistoryScreen extends StatefulWidget {
  const FamilyHistoryScreen({super.key});

  @override
  State<FamilyHistoryScreen> createState() => _FamilyHistoryScreenState();
}

class _FamilyHistoryScreenState extends State<FamilyHistoryScreen> {
  String _filter = 'today';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final canViewEvents =
            state.careDashboard?.permissions['view_events'] ?? true;
        final all = state.careHistory;
        final filtered = _applyFilter(all, _filter);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Patient Timeline',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    try {
                      await state.refreshCareHistory(limit: 220);
                    } catch (_) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to refresh history.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh history',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Today'),
                  selected: _filter == 'today',
                  onSelected: (_) => setState(() => _filter = 'today'),
                ),
                ChoiceChip(
                  label: const Text('Week'),
                  selected: _filter == 'week',
                  onSelected: (_) => setState(() => _filter = 'week'),
                ),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!canViewEvents)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Events are hidden by patient permissions.'),
                ),
              )
            else
            if (filtered.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No events in this range.'),
                ),
              )
            else
              ...filtered.map(
                (event) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(_iconFor(event)),
                    title: Text(event.title),
                    subtitle: Text(
                      '${event.message}\n${_formatTimestamp(event.timestamp)}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

List<CareEventItem> _applyFilter(List<CareEventItem> items, String filter) {
  if (filter == 'all') {
    return items;
  }
  final now = DateTime.now();
  return items.where((item) {
    final dt = DateTime.tryParse(item.timestamp)?.toLocal();
    if (dt == null) {
      return false;
    }
    if (filter == 'today') {
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }
    return now.difference(dt).inDays < 7;
  }).toList();
}

IconData _iconFor(CareEventItem event) {
  if (event.type.contains('critical')) {
    return Icons.crisis_alert_outlined;
  }
  if (event.type.contains('warning')) {
    return Icons.warning_amber_outlined;
  }
  if (event.type.contains('location')) {
    return Icons.place_outlined;
  }
  if (event.type.contains('taken')) {
    return Icons.check_circle_outline;
  }
  return Icons.info_outline;
}

String _formatTimestamp(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) {
    return iso;
  }
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
