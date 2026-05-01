import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/alert_event_model.dart';
import '../../state/app_state.dart';

class FamilyAlertsScreen extends StatefulWidget {
  const FamilyAlertsScreen({super.key});

  @override
  State<FamilyAlertsScreen> createState() => _FamilyAlertsScreenState();
}

class _FamilyAlertsScreenState extends State<FamilyAlertsScreen> {
  bool _loading = true;
  String? _error;
  String _filter = 'important';
  List<AlertEventModel> _alerts = <AlertEventModel>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final alerts = await context.read<AppState>().fetchUnreadAlerts();
      if (!mounted) {
        return;
      }
      setState(() {
        _alerts = alerts;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not load alerts.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(AlertEventModel alert) async {
    try {
      await context.read<AppState>().markAlertRead(alert.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _alerts = _alerts.where((a) => a.id != alert.id).toList();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark alert as read.')),
      );
    }
  }

  List<AlertEventModel> _filteredAlerts() {
    if (_filter == 'all') {
      return _alerts;
    }
    return _alerts.where(_isImportant).toList();
  }

  bool _isImportant(AlertEventModel alert) {
    final type = alert.type.toLowerCase();
    return type.contains('critical') ||
        type.contains('no_response') ||
        type.contains('warning') ||
        type.contains('dismissed') ||
        type.contains('snooze');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAlerts();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Alerts', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh alerts',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('Important'),
                selected: _filter == 'important',
                onSelected: (_) => setState(() => _filter = 'important'),
              ),
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == 'all',
                onSelected: (_) => setState(() => _filter = 'all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_error!),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('No alerts in this filter.'),
              ),
            )
          else
            ...filtered.map(
              (alert) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_iconForType(alert.type)),
                  title: Text(alert.title),
                  subtitle: Text(
                    '${alert.message}\n${_formatTimestamp(alert.createdAt)}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    onPressed: () => _markAsRead(alert),
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Mark read',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData _iconForType(String typeRaw) {
  final type = typeRaw.toLowerCase();
  if (type.contains('critical') || type.contains('no_response')) {
    return Icons.crisis_alert_outlined;
  }
  if (type.contains('warning') || type.contains('snooze')) {
    return Icons.warning_amber_outlined;
  }
  if (type.contains('dismissed')) {
    return Icons.cancel_outlined;
  }
  return Icons.notifications_active_outlined;
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
