import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static const Color brand = Color(0xFF0B6E4F);
  static const Color brandDark = Color(0xFF07503A);
  static const Color brandTint = Color(0xFFE4F1EA);
  static const Color pageBackground = Color(0xFFF6F7F9);
  static const Color border = Color(0xFFECEEF2);
  static const Color mutedText = Color(0xFF6B7280);

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: pageBackground,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: brandTint,
        elevation: 0,
        height: 68,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF111827),
      ),
    );
  }
}
