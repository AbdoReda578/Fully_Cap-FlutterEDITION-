import 'package:flutter/material.dart';

import '../../core/brand_palette.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading your data...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textColor = BrandPalette.textPrimaryByMode(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: BrandPalette.pageGradient(context),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    BrandPalette.primaryViolet,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
