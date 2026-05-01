import 'package:flutter/material.dart';

import '../../core/brand_palette.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final titleColor = BrandPalette.textPrimaryByMode(context);
    final subtitleColor = BrandPalette.textSecondaryByMode(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: BrandPalette.pageGradient(context),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.medication_liquid_rounded,
                color: BrandPalette.primaryViolet,
                size: 72,
              ),
              const SizedBox(height: 16),
              Text(
                'MedReminder',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stay consistent. Stay safe.',
                style: TextStyle(color: subtitleColor, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
