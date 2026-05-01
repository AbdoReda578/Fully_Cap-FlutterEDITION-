import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/due_reminder_occurrence.dart';
import '../../core/brand_palette.dart';
import '../../state/app_state.dart';
import '../widgets/reminder_alert_modal.dart';
import 'add_reminder_screen.dart';
import 'dashboard_screen.dart';
import 'family_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  Timer? _alertTimer;
  Timer? _alarmTimer;
  Timer? _criticalTimer;

  bool _showingDialog = false;
  bool _showingTitleUnlockDialog = false;
  DueReminderOccurrence? _showingOccurrence;
  bool _noResponseFired = false;
  bool _lastOffline = false;
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _state.addListener(_onAppStateChanged);
    _lastOffline = _state.isOffline;

    // Alerts are backend-driven; keep them best-effort and non-blocking.
    _alertTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_checkAlerts());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAppStateChanged();
      unawaited(_checkAlerts());
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
    if (!mounted || _showingDialog) {
      return;
    }

    final offlineNow = _state.isOffline;
    if (offlineNow != _lastOffline) {
      _lastOffline = offlineNow;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              offlineNow
                  ? 'Offline: reminders will still fire locally. Sync will resume when online.'
                  : 'Back online: syncing...',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }

    if (!_showingTitleUnlockDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_showPendingProfileUnlock());
      });
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

  Future<void> _showPendingProfileUnlock() async {
    if (!mounted || _showingDialog || _showingTitleUnlockDialog) {
      return;
    }

    final state = context.read<AppState>();
    final unlocked = state.consumePendingProfileUnlock();
    if (unlocked == null) {
      return;
    }

    _showingTitleUnlockDialog = true;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile reward unlocked',
      barrierColor: BrandPalette.shadowSoft,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (BuildContext context, _, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _TitleUnlockDialog(
              title: unlocked.label,
              description: unlocked.description,
              isSecret: unlocked.isSecret,
              kind: unlocked.kind,
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            );
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: curved, child: child),
            );
          },
    );

    _showingTitleUnlockDialog = false;

    if (mounted) {
      _onAppStateChanged();
    }
  }

  void _pulseAlert(AppState state) {
    // Browser/mobile may block sound until a user gesture; we attempt anyway.
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Critical alert queued.')));
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

      final first = alerts.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${first.title}: ${first.message}')),
      );

      // Acknowledge all unread alerts we just pulled.
      for (final alert in alerts) {
        unawaited(state.markAlertRead(alert.id));
      }
    } catch (_) {
      // Ignore alert polling failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      DashboardScreen(onAddReminderTap: () => setState(() => _index = 1)),
      const AddReminderScreen(),
      const FamilyScreen(),
      const ProfileScreen(),
      const SettingsScreen(),
    ];

    final titles = <String>[
      'Dashboard',
      'Add Reminder',
      'Family',
      'Profile',
      'Settings',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: <Widget>[
          if (context.watch<AppState>().isOffline)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.wifi_off_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          IconButton(
            onPressed: () async {
              try {
                await context.read<AppState>().refreshAll();
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
        onDestinationSelected: (int value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_alert_outlined),
            selectedIcon: Icon(Icons.add_alert),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Family',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
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

class _TitleUnlockDialog extends StatelessWidget {
  const _TitleUnlockDialog({
    required this.title,
    required this.description,
    required this.isSecret,
    required this.kind,
  });

  final String title;
  final String description;
  final bool isSecret;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final isDark = BrandPalette.isDark(context);
    final titleColor = BrandPalette.textPrimaryByMode(context);
    final subtitleColor = BrandPalette.textSecondaryByMode(context);

    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.elasticOut,
        builder: (BuildContext context, double value, Widget? child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: BrandPalette.pageGradient(context),
            border: Border.all(color: BrandPalette.borderByMode(context)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                blurRadius: 18,
                spreadRadius: 1,
                offset: Offset(0, 8),
                color: BrandPalette.shadowSoft,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                color: BrandPalette.primaryViolet,
                size: 44,
              ),
              const SizedBox(height: 8),
              Text(
                isSecret
                    ? 'Secret ${kind == 'frame' ? 'Frame' : 'Title'} Unlocked!'
                    : '${kind == 'frame' ? 'Frame' : 'Title'} Unlocked!',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? BrandPalette.primaryViolet
                      : BrandPalette.primaryDeep,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: subtitleColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Awesome'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
