import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/due_reminder_occurrence.dart';
import '../../state/app_state.dart';
import '../widgets/reminder_alert_modal.dart';
import 'family_alerts_screen.dart';
import 'family_dashboard_screen.dart';
import 'family_history_screen.dart';
import 'family_link_screen.dart';
import 'settings_screen.dart';

class FamilyHomeShell extends StatefulWidget {
  const FamilyHomeShell({super.key});

  @override
  State<FamilyHomeShell> createState() => _FamilyHomeShellState();
}

class _FamilyHomeShellState extends State<FamilyHomeShell> {
  int _index = 0;
  Timer? _alertTimer;
  Timer? _alarmTimer;
  Timer? _criticalTimer;
  bool _lastOffline = false;
  bool _showingDialog = false;
  bool _noResponseFired = false;
  late final AppState _state;
  DueReminderOccurrence? _showingOccurrence;
  final Set<String> _surfacedAlertIds = <String>{};

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _state.addListener(_onAppStateChanged);
    _lastOffline = _state.isOffline;

    _alertTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_checkAlerts());
      unawaited(_state.pollDueRemindersNow());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_state.refreshCareData());
      unawaited(_checkAlerts());
      unawaited(_state.pollDueRemindersNow());
      _onAppStateChanged();
    });
  }

  @override
  void dispose() {
    _state.removeListener(_onAppStateChanged);
    _alertTimer?.cancel();
    _alarmTimer?.cancel();
    _criticalTimer?.cancel();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) {
      return;
    }
    final offlineNow = _state.isOffline;
    if (offlineNow != _lastOffline) {
      _lastOffline = offlineNow;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            offlineNow
                ? 'Offline mode: monitoring data may be stale until reconnect.'
                : 'Back online: refreshing care dashboard...',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (_showingDialog) {
      return;
    }

    final active = _state.activeDueReminder;
    if (active == null) {
      return;
    }
    if (_showingOccurrence?.occurrenceId == active.occurrenceId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showDueDialog(active));
    });
  }

  void _pulseAlert(AppState state) {
    unawaited(state.playAlertSound());
    unawaited(state.vibrateAlert());
  }

  void _startAlarmPulse(AppState state) {
    _alarmTimer?.cancel();
    _pulseAlert(state);
    _alarmTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pulseAlert(state);
    });
  }

  void _startCriticalTimer(AppState state, DueReminderOccurrence occurrence) {
    _criticalTimer?.cancel();
    _criticalTimer = Timer(Duration(minutes: state.criticalDelayMinutes), () {
      unawaited(_handleNoResponse(occurrence));
    });
  }

  Future<void> _handleNoResponse(DueReminderOccurrence occurrence) async {
    if (!mounted) {
      return;
    }
    if (_showingOccurrence?.occurrenceId != occurrence.occurrenceId) {
      return;
    }
    if (_noResponseFired) {
      return;
    }

    _noResponseFired = true;

    try {
      final state = context.read<AppState>();
      await state.noResponse(occurrence);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Critical alert queued.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record critical alert.')),
        );
      }
    }

    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _handleAction(
    DueReminderOccurrence occurrence,
    String action,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }

    final state = context.read<AppState>();
    try {
      if (action == 'taken') {
        await state.markTaken(occurrence);
      } else if (action == 'dismiss') {
        await state.dismiss(occurrence);
      } else if (action == 'snooze') {
        await state.snooze5m(occurrence);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed. Please try again.')),
      );
    }
  }

  Future<void> _showDueDialog(DueReminderOccurrence occurrence) async {
    if (!mounted || _showingDialog) {
      return;
    }

    final state = context.read<AppState>();
    _showingOccurrence = occurrence;
    _showingDialog = true;
    _noResponseFired = false;

    _startAlarmPulse(state);
    _startCriticalTimer(state, occurrence);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ReminderAlertModal(
          medName: occurrence.medName,
          dose: occurrence.dose,
          time: occurrence.timeLabel,
          forUser: occurrence.forUser,
          snoozeCount: state.snoozeCountFor(occurrence.reminderLocalId),
          onTaken: () => _handleAction(occurrence, 'taken'),
          onSnooze: () => _handleAction(occurrence, 'snooze'),
          onDismiss: () => _handleAction(occurrence, 'dismiss'),
        );
      },
    );

    _alarmTimer?.cancel();
    _criticalTimer?.cancel();
    _showingDialog = false;
    _showingOccurrence = null;
    _onAppStateChanged();
  }

  Future<void> _checkAlerts() async {
    if (_showingDialog || _showingOccurrence != null) {
      return;
    }
    final state = context.read<AppState>();
    try {
      final alerts = await state.fetchUnreadAlerts();
      if (!mounted || alerts.isEmpty) {
        return;
      }

      final unseen = alerts
          .where((alert) => !_surfacedAlertIds.contains(alert.id))
          .toList();
      if (unseen.isEmpty) {
        return;
      }

      final first = unseen.first;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${first.title}: ${first.message}')));
      for (final alert in unseen) {
        _surfacedAlertIds.add(alert.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const FamilyDashboardScreen(),
      const FamilyHistoryScreen(),
      const FamilyAlertsScreen(),
      const FamilyLinkScreen(),
      const SettingsScreen(),
    ];

    final titles = <String>[
      'Family Dashboard',
      'History',
      'Alerts',
      'Link',
      'Settings',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: <Widget>[
          if (context.watch<AppState>().isOffline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.wifi_off_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          IconButton(
            onPressed: () async {
              try {
                await context.read<AppState>().refreshAll();
                if (!context.mounted) {
                  return;
                }
                unawaited(context.read<AppState>().pollDueRemindersNow());
              } catch (_) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refresh failed.')),
                );
              }
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => context.read<AppState>().logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Link',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
