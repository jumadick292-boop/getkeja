import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/app/theme/app_theme.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';

void main() {
  test('GetKeja brand colors match the shared palette', () {
    expect(AppColors.navy, const Color(0xFF1B2A4A));
    expect(AppColors.brand, const Color(0xFF00A86B));
    expect(AppColors.terracotta, const Color(0xFFE07A5F));
    expect(AppColors.text, const Color(0xFF2B2D42));
    expect(AppColors.pageBackground, const Color(0xFFF8F9FA));
    expect(AppColors.warning, const Color(0xFFF26419));
  });

  test('light and dark themes share the mobile design system', () {
    final lightTheme = AppTheme.light();
    final darkTheme = AppTheme.dark();

    expect(lightTheme.useMaterial3, isTrue);
    expect(lightTheme.colorScheme.primary, AppColors.brand);
    expect(lightTheme.colorScheme.onPrimary, AppColors.navy);
    expect(lightTheme.scaffoldBackgroundColor, AppColors.pageBackground);
    expect(lightTheme.textTheme.titleLarge, isNotNull);
    expect(darkTheme.brightness, Brightness.dark);
    expect(darkTheme.scaffoldBackgroundColor, AppColors.navy);
    expect(darkTheme.colorScheme.onSurface, AppColors.pageBackground);
  });
}
