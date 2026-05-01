import 'package:flutter/material.dart';

import '../../core/brand_palette.dart';

class ReminderAlertModal extends StatelessWidget {
  const ReminderAlertModal({
    super.key,
    required this.medName,
    required this.dose,
    required this.time,
    required this.forUser,
    required this.snoozeCount,
    required this.onTaken,
    required this.onSnooze,
    required this.onDismiss,
  });

  final String medName;
  final String dose;
  final String time;
  final String forUser;
  final int snoozeCount;
  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDark = BrandPalette.isDark(context);
    final compact = width < 420;
    final titleSize = compact ? 32.0 : 40.0;
    final medNameSize = compact ? 28.0 : 34.0;
    final actionFontSize = compact ? 18.0 : 22.0;
    final dialogBg = BrandPalette.surfaceByMode(context);
    final dialogBorder = BrandPalette.borderByMode(context);
    final sectionBg = BrandPalette.surfaceSoftByMode(context);
    final textPrimary = BrandPalette.textPrimaryByMode(context);
    final textSecondary = BrandPalette.textSecondaryByMode(context);
    final innerBorder = isDark ? BrandPalette.darkBorder : BrandPalette.surfaceSoft;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: dialogBg,
          border: Border.all(color: dialogBorder),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              blurRadius: 26,
              color: BrandPalette.shadowSoft,
              offset: Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.medication_rounded,
                size: 54,
                color: BrandPalette.primaryViolet,
              ),
              const SizedBox(height: 8),
              Text(
                'Medication Reminder!',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: sectionBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: dialogBorder),
                ),
                padding: const EdgeInsets.all(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: dialogBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: innerBorder),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        blurRadius: 8,
                        color: BrandPalette.shadowSoft,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        medName,
                        style: TextStyle(
                          fontSize: medNameSize,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _detailRow(
                        'Dose',
                        dose,
                        labelColor: textSecondary,
                        valueColor: textPrimary,
                      ),
                      const SizedBox(height: 6),
                      _detailRow(
                        'Time',
                        time,
                        labelColor: textSecondary,
                        valueColor: textPrimary,
                      ),
                      const SizedBox(height: 6),
                      _detailRow(
                        'For',
                        forUser,
                        labelColor: textSecondary,
                        valueColor: textPrimary,
                      ),
                      if (snoozeCount > 0) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Snoozed $snoozeCount times',
                          style: const TextStyle(
                            color: BrandPalette.primaryDeep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 14,
                children: <Widget>[
                  ElevatedButton.icon(
                    onPressed: onTaken,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Taken'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandPalette.primaryViolet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontSize: actionFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onSnooze,
                    icon: const Icon(Icons.schedule_rounded),
                    label: const Text('Snooze 5min'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandPalette.primaryDeep,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontSize: actionFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Dismiss'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandPalette.primaryViolet,
                  side: BorderSide(
                    color: isDark
                        ? BrandPalette.darkBorder
                        : BrandPalette.borderStrong,
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: TextStyle(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    required Color labelColor,
    required Color valueColor,
  }) {
    return Row(
      children: <Widget>[
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: labelColor,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
