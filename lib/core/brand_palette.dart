import 'package:flutter/material.dart';

class BrandPalette {
  const BrandPalette._();

  // Primary brand (Calm Health-Tech Gradient)
  static const Color primaryBlue = Color(0xFF5F8DFF);
  static const Color primaryViolet = Color(0xFF7A6BFF);
  static const Color primaryDeep = Color(0xFF6C5DD3);

  // Accent CTA
  static const Color accentCyan = Color(0xFF32D2FF);
  static const Color accentTeal = Color(0xFF22C1C3);

  // Light theme base
  static const Color background = Color(0xFFF8F9FF);
  static const Color surface = Colors.white;
  static const Color surfaceSoft = Color(0xFFECE8FF);
  static const Color surfaceSoftAlt = Color(0xFFF2EFFF);
  static const Color borderSoft = Color(0xFFD9D9FF);
  static const Color borderStrong = Color(0xFFC9CCFF);
  static const Color textPrimary = Color(0xFF2E3267);
  static const Color textSecondary = Color(0xFF5E6698);
  static const Color textTertiary = Color(0xFF7A82B0);
  static const Color textOnPrimary = Colors.white;

  // Text on dark/gradient
  static const Color textHeadline = Color(0xFFCFE6FF);
  static const Color textBody = Color(0xFFE9ECFF);
  static const Color textMuted = Color(0xFFB8C2FF);

  // Dark theme base
  static const Color darkBackground = Color(0xFF0D1020);
  static const Color darkSurface = Color(0xFF151B32);
  static const Color darkSurfaceSoft = Color(0xFF202949);
  static const Color darkBorder = Color(0xFF353E67);
  static const Color darkTextPrimary = Color(0xFFE9ECFF);
  static const Color darkTextSecondary = Color(0xFFC0C9F0);
  static const Color darkTextTertiary = Color(0xFF95A1D4);

  // Glass surfaces
  static const Color surfaceGlass = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color borderGlass = Color(0x26FFFFFF); // rgba(255,255,255,0.15)
  static const Color shadowSoft = Color(0x1F000000); // rgba(0,0,0,0.12)

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFCFDFF),
      Color(0xFFF4F2FF),
      Color(0xFFECE8FF),
    ],
    stops: <double>[0, 0.45, 1],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF0D1020),
      Color(0xFF131833),
      Color(0xFF191F42),
    ],
    stops: <double>[0, 0.45, 1],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[primaryViolet, primaryDeep],
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static LinearGradient pageGradient(BuildContext context) =>
      isDark(context) ? darkGradient : primaryGradient;

  static Color surfaceByMode(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color surfaceSoftByMode(BuildContext context) =>
      isDark(context) ? darkSurfaceSoft : surfaceSoft;

  static Color borderByMode(BuildContext context) =>
      isDark(context) ? darkBorder : borderSoft;

  static Color textPrimaryByMode(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryByMode(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textTertiaryByMode(BuildContext context) =>
      isDark(context) ? darkTextTertiary : textTertiary;
}
