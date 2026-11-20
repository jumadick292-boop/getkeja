// Design system - Colors, Typography, Spacing.

import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary brand colors
  static const Color navy = Color(0xFF1B2A4A);
  static const Color brand = Color(0xFF00A86B);
  static const Color terracotta = Color(0xFFE07A5F);
  static const Color warning = Color(0xFFF26419);
  static const Color warningForeground = Color(0xFF172546);
  static const Color brandTint = Color(0xFFE6F5EE);

  // Neutrals
  static const Color pageBackground = Color(0xFFF8F9FA);
  static const Color border = Color(0xFFE3E6EA);
  static const Color text = Color(0xFF2B2D42);
  static const Color mutedText = Color(0xFF626575);
  static const Color error = Color(0xFFB42318);
  static const Color success = Color(0xFF0A7F3C);
  static const Color surfaceWhite = Colors.white;

  // Semantic colors (light theme)
  static const Color lightPrimary = brand;
  static const Color lightOnPrimary = navy;
  static const Color lightSecondary = terracotta;
  static const Color lightOnSecondary = navy;
  static const Color lightTertiary = warning;
  static const Color lightOnTertiary = warningForeground;
  static const Color lightPrimaryContainer = brandTint;
  static const Color lightOnPrimaryContainer = navy;
  static const Color lightSurface = surfaceWhite;
  static const Color lightOnSurface = text;
  static const Color lightOnSurfaceVariant = mutedText;
  static const Color lightOutline = border;
  static const Color lightError = error;
  static const Color lightErrorContainer = Color(0xFFFDECEA);
  static const Color lightOnErrorContainer = Color(0xFF6E1A15);
  static const Color lightSuccessContainer = Color(0xFFE6F5EE);
  static const Color lightOnSuccessContainer = Color(0xFF0A7F3C);

  // Semantic colors (dark theme)
  static const Color darkPrimary = Color(0xFF4CD98C);
  static const Color darkOnPrimary = navy;
  static const Color darkSecondary = Color(0xFFF0A08B);
  static const Color darkOnSecondary = navy;
  static const Color darkTertiary = Color(0xFFFF9F43);
  static const Color darkOnTertiary = warningForeground;
  static const Color darkPrimaryContainer = Color(0xFF315342);
  static const Color darkOnPrimaryContainer = pageBackground;
  static const Color darkSurface = Color(0xFF243454);
  static const Color darkOnSurface = pageBackground;
  static const Color darkOnSurfaceVariant = Color(0xFFC4CCDA);
  static const Color darkOutline = Color(0xFF53627C);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkErrorContainer = Color(0xFF6E1A15);
  static const Color darkOnErrorContainer = Color(0xFFFFB4AB);
  static const Color darkSuccessContainer = Color(0xFF315342);
  static const Color darkOnSuccessContainer = Color(0xFF4CD98C);

  // Status colors
  static const Color pending = Color(0xFFF5A623);
  static const Color verified = Color(0xFF00A86B);
  static const Color rejected = Color(0xFFB42318);
  static const Color inactive = Color(0xFF9EA3AE);
}

abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  // Display styles
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
  );

  // Headline styles
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.29,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.33,
  );

  // Title styles
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  // Body styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  // Label styles
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.33,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.45,
  );
}

abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 24.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(20.0);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0);
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0);
}

abstract final class AppBorderRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xlarge = 24.0;
  static const double round = 9999.0;

  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(large));
  static const BorderRadius xlargeRadius = BorderRadius.all(Radius.circular(xlarge));
  static const BorderRadius roundRadius = BorderRadius.all(Radius.circular(round));
}

abstract final class AppElevation {
  static const List<BoxShadow> level0 = [];
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

abstract final class AppAnimation {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);

  static const Curve standard = Curves.easeInOut;
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve decelerated = Curves.easeOutQuart;
}