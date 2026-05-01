import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_palette.dart';
import '../../models/care_patient_model.dart';
import '../../state/app_state.dart';

class FamilyDashboardScreen extends StatelessWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (!state.isFamilyRole) {
          return const Center(
            child: Text('Family dashboard is available for family users only.'),
          );
        }

        final patients = state.carePatients;
        final dashboard = state.careDashboard;

        if (patients.isEmpty || dashboard == null) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'No linked patients yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Link to a patient from the Link tab using invite code or QR.',
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: state.refreshCareData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final selected = state.selectedCarePatientEmail ?? dashboard.patientEmail;
        final statusColor = dashboard.isOnline
            ? const Color(0xFF22C55E)
            : BrandPalette.primaryDeep;
        final canViewLocation = dashboard.permissions['view_location'] ?? true;
        final canViewEvents = dashboard.permissions['view_events'] ?? true;

        return RefreshIndicator(
          onRefresh: state.refreshCareData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (patients.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Patient',
                    prefixIcon: Icon(Icons.person_search_outlined),
                  ),
                  items: patients
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p.patientEmail,
                          child: Text(p.patientEmail),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      state.selectCarePatient(value);
                    }
                  },
                ),
              if (patients.length > 1) const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Patient Status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Chip(
                            label: Text(
                              dashboard.isOnline ? 'Online' : 'Offline',
                            ),
                            backgroundColor: statusColor.withValues(alpha: 0.14),
                            side: BorderSide(
                              color: statusColor.withValues(alpha: 0.34),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Patient: ${dashboard.patientEmail}'),
                      Text(
                        'Last update: ${_formatTimestamp(dashboard.lastUpdateAt)}',
                      ),
                      Text(
                        'Last seen: ${_formatTimestamp(dashboard.lastSeenAt)}',
                      ),
                      if (!canViewLocation || !canViewEvents) ...<Widget>[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (!canViewLocation)
                              const Chip(
                                avatar: Icon(Icons.lock_outline, size: 16),
                                label: Text('Location access disabled'),
                              ),
                            if (!canViewEvents)
                              const Chip(
                                avatar: Icon(Icons.lock_outline, size: 16),
                                label: Text('Events access disabled'),
                              ),
                          ],
                        ),
                      ],
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
                      Text('Live Map', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (!canViewLocation)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Location sharing is disabled for your account.',
                          ),
                        )
                      else
                        SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: BrandPalette.pageGradient(context),
                                border: Border.all(
                                  color: BrandPalette.borderByMode(context),
                                ),
                              ),
                              child: CustomPaint(
                                painter: _RouteMapPainter(
                                  points: dashboard.path,
                                  safeZone: dashboard.safeZone,
                                  isDark: BrandPalette.isDark(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (canViewLocation)
                        Text(
                          dashboard.lastLocation == null
                              ? 'No location reported yet.'
                              : 'Latest: ${dashboard.lastLocation!.lat.toStringAsFixed(5)}, '
                                    '${dashboard.lastLocation!.lng.toStringAsFixed(5)}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _StatsGrid(dashboard: dashboard),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Recent Events',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => state.refreshCareHistory(limit: 180),
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (!canViewEvents)
                        const Text('Events are hidden by patient permissions.')
                      else if (dashboard.recentEvents.isEmpty)
                        const Text('No recent events.')
                      else
                        ...dashboard.recentEvents.take(8).map(
                          (e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_eventIcon(e.type)),
                            title: Text(e.title),
                            subtitle: Text(
                              '${e.message}\n${_formatTimestamp(e.timestamp)}',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.dashboard});

  final CarePatientDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final stats = dashboard.stats;

    Widget item(String label, String value, IconData icon) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).cardColor,
          border: Border.all(color: BrandPalette.borderByMode(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: BrandPalette.primaryViolet),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 720 ? 3 : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: <Widget>[
        item('Taken Today', '${stats.takenToday}', Icons.check_circle_outline),
        item('Taken Week', '${stats.takenWeek}', Icons.calendar_view_week),
        item('Alerts Today', '${stats.alertsToday}', Icons.warning_amber_outlined),
        item('Alerts Week', '${stats.alertsWeek}', Icons.notification_important_outlined),
        item(
          'Outside Safe Zone',
          '${stats.timeOutsideSafeZoneMinutes} min',
          Icons.place_outlined,
        ),
        item(
          'Last Movement',
          _shortTimestamp(stats.lastMovementAt),
          Icons.directions_walk_outlined,
        ),
      ],
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.points,
    required this.safeZone,
    required this.isDark,
  });

  final List<CareLocationPoint> points;
  final Map<String, dynamic>? safeZone;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final bgGrid = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final dx = size.width * i / 6;
      final dy = size.height * i / 6;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), bgGrid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), bgGrid);
    }

    if (points.isEmpty) {
      return;
    }

    final lats = points.map((e) => e.lat).toList();
    final lngs = points.map((e) => e.lng).toList();
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min);
    final maxLng = lngs.reduce(math.max);

    double normX(double lng) {
      if ((maxLng - minLng).abs() < 0.000001) {
        return size.width / 2;
      }
      return ((lng - minLng) / (maxLng - minLng)) * (size.width - 24) + 12;
    }

    double normY(double lat) {
      if ((maxLat - minLat).abs() < 0.000001) {
        return size.height / 2;
      }
      final n = (lat - minLat) / (maxLat - minLat);
      return (1 - n) * (size.height - 24) + 12;
    }

    final routePaint = Paint()
      ..color = BrandPalette.primaryViolet
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final dx = normX(p.lng);
      final dy = normY(p.lat);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    canvas.drawPath(path, routePaint);

    final last = points.last;
    final lastOffset = Offset(normX(last.lng), normY(last.lat));

    final safeLatRaw = safeZone?['lat'];
    final safeLngRaw = safeZone?['lng'];
    final safeRadiusRaw = safeZone?['radius_m'];
    final safeLat = safeLatRaw == null
        ? null
        : double.tryParse(safeLatRaw.toString());
    final safeLng = safeLngRaw == null
        ? null
        : double.tryParse(safeLngRaw.toString());
    final safeRadius = safeRadiusRaw == null
        ? null
        : double.tryParse(safeRadiusRaw.toString());
    if (safeLat != null && safeLng != null && safeRadius != null && safeRadius > 0) {
      final center = Offset(normX(safeLng), normY(safeLat));
      final circlePaint = Paint()
        ..color = BrandPalette.primaryBlue.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = BrandPalette.primaryBlue.withValues(alpha: 0.46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      const safeRadiusPx = 28.0;
      canvas.drawCircle(center, safeRadiusPx, circlePaint);
      canvas.drawCircle(center, safeRadiusPx, borderPaint);
    }

    final pointPaint = Paint()
      ..color = BrandPalette.primaryDeep
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastOffset, 6.5, pointPaint);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.safeZone != safeZone;
  }
}

String _formatTimestamp(String? iso) {
  if (iso == null || iso.trim().isEmpty) {
    return '-';
  }
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

String _shortTimestamp(String? iso) {
  final text = _formatTimestamp(iso);
  if (text == '-') {
    return text;
  }
  return text.length > 5 ? text.substring(text.length - 5) : text;
}

IconData _eventIcon(String type) {
  if (type.contains('critical')) {
    return Icons.crisis_alert_outlined;
  }
  if (type.contains('warning')) {
    return Icons.warning_amber_outlined;
  }
  if (type.contains('taken')) {
    return Icons.check_circle_outline;
  }
  if (type.contains('location')) {
    return Icons.place_outlined;
  }
  return Icons.info_outline;
}
